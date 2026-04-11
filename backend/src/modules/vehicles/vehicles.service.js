const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

exports.getAllVehiclesBySociety = async (societyId) => {
  return await prisma.vehicle.findMany({
    where: { societyId },
  });
};

exports.createVehicle = async (data) => {
  return await prisma.vehicle.create({ data });
};

exports.updateVehicle = async (id, data) => {
  return await prisma.vehicle.update({
    where: { id },
    data,
  });
};

exports.deleteVehicle = async (id) => {
  return await prisma.vehicle.delete({
    where: { id },
  });
};
