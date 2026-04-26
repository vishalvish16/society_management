const prisma = require('../src/config/db');

/**
 * Cleanup duplicate plans created with different casing / legacy seed scripts.
 *
 * - Canonical plan names are: basic | standard | premium (lowercase)
 * - Migrates societies from duplicates to canonical
 * - Deactivates duplicate plans (only if no societies still reference them)
 */
async function main() {
  const canonical = ['basic', 'standard', 'premium'];

  const result = await prisma.$transaction(async (tx) => {
    const plans = await tx.plan.findMany({
      select: { id: true, name: true, isActive: true },
    });

    const canonicalByName = new Map(
      plans
        .filter((p) => canonical.includes(String(p.name)) && String(p.name) === String(p.name).toLowerCase())
        .map((p) => [String(p.name), p.id]),
    );

    const missing = canonical.filter((n) => !canonicalByName.has(n));
    if (missing.length) {
      throw new Error(`Missing canonical plans: ${missing.join(', ')} (run seed first)`);
    }

    const dups = plans.filter((p) => {
      const name = String(p.name || '');
      const lower = name.toLowerCase();
      return canonical.includes(lower) && name !== lower;
    });

    let migratedSocieties = 0;
    for (const dup of dups) {
      const targetId = canonicalByName.get(String(dup.name).toLowerCase());
      const res = await tx.society.updateMany({
        where: { planId: dup.id },
        data: { planId: targetId },
      });
      migratedSocieties += res.count || 0;
    }

    const nonCanonical = plans.filter((p) => {
      const name = String(p.name || '');
      return !(canonical.includes(name) && name === name.toLowerCase());
    });

    let deactivatedPlans = 0;
    const skippedPlans = [];
    for (const p of nonCanonical) {
      const refCount = await tx.society.count({ where: { planId: p.id } });
      if (refCount > 0) {
        skippedPlans.push({ id: p.id, name: p.name, societies: refCount });
        continue;
      }
      if (p.isActive) {
        await tx.plan.update({ where: { id: p.id }, data: { isActive: false } });
      }
      deactivatedPlans += 1;
    }

    return { migratedSocieties, deactivatedPlans, skippedPlans };
  });

  console.log('Cleanup complete:', result);
}

main()
  .catch((e) => {
    console.error('Cleanup error:', e.message);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

