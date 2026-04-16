const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function checkNotifications() {
  try {
    const notifications = await prisma.notification.findMany({
      where: { targetType: 'role', targetId: 'MEMBER' },
      orderBy: { sentAt: 'desc' },
      take: 5
    });
    console.log(JSON.stringify(notifications, null, 2));
  } catch (error) {
    console.error(error);
  } finally {
    await prisma.$disconnect();
  }
}

checkNotifications();
