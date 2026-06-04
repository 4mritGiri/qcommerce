# lib/qcommerce/ledger/workers/checkpoint_balances_worker.ex
defmodule Qcommerce.Ledger.Workers.CheckpointBalancesWorker do
  @moduledoc """
  Oban recurring job — materializes sharded balance checkpoints every 15 min.
  """

  use Oban.Worker,
    queue: :checkpoint,
    max_attempts: 3,
    unique: [period: 1_200, fields: [:worker], keys: []]

  require Logger

  alias Qcommerce.Repo
  alias Qcommerce.Ledger.BalanceCheckpoint

  @impl Oban.Worker
  def perform(%Oban.Job{id: job_id}) do
    start_ms = System.monotonic_time(:millisecond)
    Logger.info("[CheckpointWorker] job=#{job_id} starting")

    boundary = capture_boundary()
    segments = fetch_active_segments(boundary)

    Logger.info(
      "[CheckpointWorker] job=#{job_id} boundary=#{DateTime.to_iso8601(boundary)} segments=#{length(segments)}"
    )

    results = Enum.map(segments, &process_segment(&1, boundary))
    written = results |> Enum.map(& &1.written) |> Enum.sum()
    skipped = results |> Enum.map(& &1.skipped) |> Enum.sum()
    errors = results |> Enum.count(&(&1.status == :error))
    duration = System.monotonic_time(:millisecond) - start_ms

    Logger.info(
      "[CheckpointWorker] job=#{job_id} written=#{written} skipped=#{skipped} errors=#{errors} duration_ms=#{duration}"
    )

    emit_telemetry(boundary, written, skipped, duration)

    if errors > 0, do: {:ok, %{partial_errors: errors}}, else: :ok
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp capture_boundary do
    %{rows: [[boundary]]} =
      Repo.query!(
        "SELECT COALESCE(MAX(inserted_at), '1970-01-01 00:00:00+00'::timestamptz) FROM journal_lines",
        []
      )

    boundary
  end

  defp fetch_active_segments(boundary) do
    Repo.query!(
      """
        SELECT DISTINCT jl.branch_id, jl.fiscal_year_id
        FROM journal_lines jl
        LEFT JOIN LATERAL (
          SELECT checkpointed_through
          FROM   balance_checkpoints bc
          WHERE  bc.branch_id      = jl.branch_id
            AND  bc.fiscal_year_id = jl.fiscal_year_id
          ORDER  BY bc.inserted_at DESC
          LIMIT  1
        ) lc ON TRUE
        WHERE jl.inserted_at <= $1
          AND (lc.checkpointed_through IS NULL OR jl.inserted_at > lc.checkpointed_through)
      """,
      [boundary]
    )
    |> Map.fetch!(:rows)
    |> Enum.map(fn [branch_id, fiscal_year_id] ->
      %{branch_id: branch_id, fiscal_year_id: fiscal_year_id}
    end)
  end

  defp process_segment(%{branch_id: branch_id, fiscal_year_id: fiscal_year_id}, boundary) do
    rows =
      Repo.query!(
        """
          SELECT
            jl.account_id,
            jl.shard_id,
            COALESCE(SUM(jl.amount) FILTER (WHERE jl.entry_type = 'debit'),  0),
            COALESCE(SUM(jl.amount) FILTER (WHERE jl.entry_type = 'credit'), 0),
            COUNT(*)
          FROM  journal_lines jl
          WHERE jl.branch_id      = $1
            AND jl.fiscal_year_id = $2
            AND jl.inserted_at   <= $3
          GROUP BY jl.account_id, jl.shard_id
        """,
        [branch_id, fiscal_year_id, boundary]
      )
      |> Map.fetch!(:rows)

    now = DateTime.utc_now()

    {to_insert, skipped} =
      Enum.reduce(rows, {[], 0}, fn [account_id, shard_id, debits, credits, count], {ins, skip} ->
        if count == 0 do
          {ins, skip + 1}
        else
          row = %{
            id: Ecto.UUID.generate(),
            branch_id: branch_id,
            account_id: account_id,
            fiscal_year_id: fiscal_year_id,
            shard_id: shard_id,
            debit_total: debits,
            credit_total: credits,
            checkpointed_through: boundary,
            entry_count: count,
            inserted_at: now
          }

          {[row | ins], skip}
        end
      end)

    {written, _} = Repo.insert_all(BalanceCheckpoint, to_insert)
    %{status: :ok, written: written, skipped: skipped}
  rescue
    e ->
      Logger.error(
        "[CheckpointWorker] segment error branch=#{branch_id}: #{Exception.message(e)}"
      )

      %{status: :error, written: 0, skipped: 0}
  end

  defp emit_telemetry(boundary, written, skipped, duration_ms) do
    age = DateTime.diff(DateTime.utc_now(), boundary, :second)

    :telemetry.execute(
      [:qcommerce, :checkpoint, :cycle_complete],
      %{
        rows_written: written,
        shards_skipped: skipped,
        duration_ms: duration_ms,
        boundary_age_seconds: age
      },
      %{worker: __MODULE__}
    )
  end
end
