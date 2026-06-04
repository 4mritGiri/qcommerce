# lib/qcommerce/ledger/workers/nightly_report_worker.ex
defmodule Qcommerce.Ledger.Workers.NightlyReportWorker do
  use Oban.Worker, queue: :reports, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    # TODO: implement nightly P&L report generation
    :ok
  end
end
