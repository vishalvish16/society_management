const { runOverdueReminderSweep, runMaintenanceBillScheduleSweep } = require('./bills.service');

let schedulerHandle = null;

function startBillingJobs() {
  if (process.env.NODE_ENV === 'test' || schedulerHandle) {
    return;
  }

  const runOverdueSweep = async () => {
    try {
      const result = await runOverdueReminderSweep();
      if (result.remindersSent > 0) {
        console.log(`[billing-jobs] sent ${result.remindersSent} overdue reminder batch(es)`);
      }
    } catch (error) {
      console.error('[billing-jobs] overdue reminder sweep failed:', error.message);
    }
  };

  const runScheduleSweep = async () => {
    try {
      const result = await runMaintenanceBillScheduleSweep();
      if (result.schedulesRun > 0) {
        console.log(`[billing-jobs] ran ${result.schedulesRun} schedule(s), created ${result.billsCreated} bill(s)`);
      }
    } catch (error) {
      console.error('[billing-jobs] bill schedule sweep failed:', error.message);
    }
  };

  // Start shortly after boot.
  setTimeout(() => {
    runScheduleSweep();
    runOverdueSweep();
  }, 10 * 1000);

  // Bill schedule sweep: every minute.
  schedulerHandle = setInterval(runScheduleSweep, 60 * 1000);

  // Overdue reminder sweep: hourly.
  setInterval(runOverdueSweep, 60 * 60 * 1000);
}

module.exports = { startBillingJobs };
