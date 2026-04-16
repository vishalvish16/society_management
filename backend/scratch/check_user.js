const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function checkAllDivyesh() {
  try {
    const users = await prisma.user.findMany({
      where: { name: { contains: 'Divyesh', mode: 'insensitive' } },
      select: { id: true, name: true, role: true, societyId: true, phone: true }
    });
    console.log(JSON.stringify(users, null, 2));
  } catch (error) {
    console.error(error);
  } finally {
    await prisma.$disconnect();
  }
}

checkAllDivyesh();
