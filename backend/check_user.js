const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const bcrypt = require('bcrypt');

async function checkUser() {
  const users = await prisma.user.findMany({
    where: {
      OR: [
        { name: 'Aakadh' },
        { name: 'Dube' }
      ]
    }
  });
  
  const password = 'Admin@123';
  for (const user of users) {
    const match = await bcrypt.compare(password, user.passwordHash);
    console.log(`User ${user.name} (${user.phone}) password match: ${match}`);
  }
  await prisma.$disconnect();
}

checkUser().catch(e => {
  console.error(e);
  process.exit(1);
});
