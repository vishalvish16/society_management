const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

exports.getAllDeliveriesBySociety = async (societyId) => {
  return await prisma.delivery.findMany({
    where: { societyId },
  });
};

exports.createDelivery = async (data) => {
  return await prisma.delivery.create({ data });
};

exports.updateDelivery = async (id, data) => {
  return await prisma.delivery.update({
    where: { id },
    data,
  });
};

exports.deleteDelivery = async (id) => {
  return await prisma.delivery.delete({
    where: { id },
  });
};
