const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

exports.getAllMoveRequestsBySociety = async (societyId) => {
  return await prisma.moveRequest.findMany({
    where: { societyId },
  });
};

exports.createMoveRequest = async (data) => {
  return await prisma.moveRequest.create({ data });
};

exports.updateMoveRequest = async (id, data) => {
  return await prisma.moveRequest.update({
    where: { id },
    data,
  });
};

exports.deleteMoveRequest = async (id) => {
  return await prisma.moveRequest.delete({
    where: { id },
  });
};
