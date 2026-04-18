const { runOverdueReminderSweep } = require('./bills.service');

let schedulerHandle = null;

function startBillingJobs() {
  if (process.env.NODE_ENV === 'test' || schedulerHandle) {
    return;
  }

  const runSweep = async () => {
    try {
      const result = await runOverdueReminderSweep();
      if (result.remindersSent > 0) {
        console.log(`[billing-jobs] sent ${result.remindersSent} overdue reminder batch(es)`);
      }
    } catch (error) {
      console.error('[billing-jobs] overdue reminder sweep failed:', error.message);
    }
  };

  setTimeout(runSweep, 10 * 1000);
  schedulerHandle = setInterval(runSweep, 60 * 60 * 1000);
}

module.exports = { startBillingJobs };
