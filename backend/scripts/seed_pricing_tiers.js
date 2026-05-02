/**
 * Seed default pricing tiers for canonical plans (basic, standard, premium).
 * Safe to re-run: skips plans that already have tiers.
 * Usage: node scripts/seed_pricing_tiers.js
 */

const prisma = require('../src/config/db');
const { DEFAULT_TIERS } = require('../src/config/planConfig');

async function main() {
  const planNames = Object.keys(DEFAULT_TIERS);

  for (const name of planNames) {
    const plan = await prisma.plan.findUnique({ where: { name } });
    if (!plan) {
      console.log(`[SKIP] Plan "${name}" not found in DB`);
      continue;
    }

    const existing = await prisma.pricingTier.count({ where: { planId: plan.id } });
    if (existing > 0) {
      console.log(`[SKIP] Plan "${name}" already has ${existing} tier(s)`);
      continue;
    }

    const tiers = DEFAULT_TIERS[name];
    await prisma.pricingTier.createMany({
      data: tiers.map((t) => ({
        planId:       plan.id,
        minUnits:     t.minUnits,
        maxUnits:     t.maxUnits,
        pricePerUnit: t.pricePerUnit,
        label:        t.label,
        sortOrder:    t.sortOrder,
      })),
    });
    console.log(`[OK]   Seeded ${tiers.length} tiers for plan "${name}"`);
  }

  console.log('Done.');
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
