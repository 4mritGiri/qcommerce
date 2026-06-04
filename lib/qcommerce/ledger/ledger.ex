# lib/qcommerce/ledger/ledger.ex
defmodule Qcommerce.Ledger do
  @moduledoc """
  Public context API for the financial ledger.

  Read operations (balance queries) live here.
  Write operations (journal creation) are handled by the Oban worker
  that processes outbox events — never called directly from controllers.

  The three-layer balance architecture:
    Layer 1 — journal_lines       (immutable ground truth)
    Layer 2 — balance_checkpoints (periodic materialized snapshot)
    Layer 3 — delta query         (journal_lines since last checkpoint)

  Current balance = checkpoint cumulative totals + delta since checkpoint.
  """

  import Ecto.Query

  alias Qcommerce.Repo
  alias Qcommerce.Core.Error
  alias Qcommerce.Ledger.{Account, Journal, JournalLine, BalanceCheckpoint}

  # ---------------------------------------------------------------------------
  # Balance queries
  # ---------------------------------------------------------------------------

  @doc """
  Returns the current net balance for an account within a branch and fiscal year.

  Sign convention (returned Decimal):
  - Positive: account has increased from zero (normal state)
  - Negative: abnormal balance — worth alerting on

  Uses checkpoint + delta pattern for efficiency.
  """
  @spec current_balance(binary(), binary(), binary()) ::
          {:ok, map()} | {:error, Error.t()}
  def current_balance(branch_id, account_id, fiscal_year_id) do
    with {:ok, account}     <- get_account(account_id),
         {:ok, checkpoints} <- fetch_latest_checkpoints(branch_id, account_id, fiscal_year_id),
         {:ok, delta}       <- fetch_delta(branch_id, account_id, fiscal_year_id, checkpoints) do

      net = compute_net_balance(checkpoints, delta, account.normal_balance)

      {:ok, %{
        account_id:           account_id,
        branch_id:            branch_id,
        net_balance:          net,
        checkpointed_through: max_boundary(checkpoints),
        delta_entry_count:    delta.entry_count,
        computed_at:          DateTime.utc_now()
      }}
    end
  end

  @doc "Branch-level balance sheet — all accounts for a branch in a fiscal year."
  def branch_balance_sheet(branch_id, fiscal_year_id) do
    accounts = Repo.all(from a in Account, where: a.is_active == true)

    results =
      Enum.map(accounts, fn account ->
        case current_balance(branch_id, account.id, fiscal_year_id) do
          {:ok, balance} -> Map.put(balance, :account, account)
          {:error, _}    -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, results}
  end

  # ---------------------------------------------------------------------------
  # Account queries
  # ---------------------------------------------------------------------------

  def get_account(id) do
    case Repo.get(Account, id) do
      nil     -> {:error, Error.not_found("Account", id)}
      account -> {:ok, account}
    end
  end

  def get_account_by_code(code) do
    case Repo.get_by(Account, code: code) do
      nil     -> {:error, Error.not_found("Account")}
      account -> {:ok, account}
    end
  end

  def list_accounts do
    {:ok, Repo.all(from a in Account, order_by: [asc: a.code])}
  end

  # ---------------------------------------------------------------------------
  # Journal queries (audit trail)
  # ---------------------------------------------------------------------------

  def list_journals(branch_id, params \\ []) do
    journals =
      Journal
      |> where([j], j.branch_id == ^branch_id)
      |> maybe_filter_fiscal_year(params[:fiscal_year_id])
      |> order_by([j], desc: j.posted_at)
      |> limit(^(params[:limit] || 50))
      |> Repo.all()

    {:ok, journals}
  end

  # ---------------------------------------------------------------------------
  # Private — balance computation
  # ---------------------------------------------------------------------------

  defp fetch_latest_checkpoints(branch_id, account_id, fiscal_year_id) do
    rows =
      from(bc in BalanceCheckpoint,
        where:    bc.branch_id      == ^branch_id,
        where:    bc.account_id     == ^account_id,
        where:    bc.fiscal_year_id == ^fiscal_year_id,
        distinct: bc.shard_id,
        order_by: [asc: bc.shard_id, desc: bc.inserted_at]
      )
      |> Repo.all()

    {:ok, rows}
  end

  defp fetch_delta(branch_id, account_id, fiscal_year_id, checkpoints) do
    epoch = ~U[1970-01-01 00:00:00Z]

    min_boundary =
      checkpoints
      |> Enum.map(& &1.checkpointed_through)
      |> Enum.reject(&is_nil/1)
      |> Enum.min(DateTime, fn -> epoch end)

    result =
      from(jl in JournalLine,
        where:  jl.branch_id      == ^branch_id,
        where:  jl.account_id     == ^account_id,
        where:  jl.fiscal_year_id == ^fiscal_year_id,
        where:  jl.inserted_at    > ^min_boundary,
        select: %{
          debits:      coalesce(sum(fragment("CASE WHEN ? = 'debit' THEN ? ELSE 0 END",
                         jl.entry_type, jl.amount)), ^Decimal.new(0)),
          credits:     coalesce(sum(fragment("CASE WHEN ? = 'credit' THEN ? ELSE 0 END",
                         jl.entry_type, jl.amount)), ^Decimal.new(0)),
          entry_count: count(jl.id)
        }
      )
      |> Repo.one()

    {:ok, result || %{debits: Decimal.new(0), credits: Decimal.new(0), entry_count: 0}}
  end

  defp compute_net_balance(checkpoints, delta, normal_balance) do
    chk_debits  = checkpoints |> Enum.map(& &1.debit_total)  |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
    chk_credits = checkpoints |> Enum.map(& &1.credit_total) |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    total_debits  = Decimal.add(chk_debits,  delta.debits)
    total_credits = Decimal.add(chk_credits, delta.credits)

    case normal_balance do
      :debit  -> Decimal.sub(total_debits,  total_credits)
      :credit -> Decimal.sub(total_credits, total_debits)
    end
  end

  defp max_boundary([]),          do: nil
  defp max_boundary(checkpoints) do
    checkpoints
    |> Enum.map(& &1.checkpointed_through)
    |> Enum.reject(&is_nil/1)
    |> Enum.max(DateTime, fn -> nil end)
  end

  defp maybe_filter_fiscal_year(query, nil), do: query
  defp maybe_filter_fiscal_year(query, fy_id) do
    where(query, [j], j.fiscal_year_id == ^fy_id)
  end
end
