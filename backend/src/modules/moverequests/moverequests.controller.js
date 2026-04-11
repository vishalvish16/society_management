const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const Joi = require('joi');

const moveRequestSchema = Joi.object({
  unitId: Joi.number().required(),
  reason: Joi.string().required(),
  status: Joi.string().valid('pending', 'approved', 'rejected').required(),
});

exports.getAllMoveRequests = async (req, res) => {
  try {
    const moveRequests = await prisma.moveRequest.findMany({
      where: { societyId: req.user.societyId },
    });
    res.json(moveRequests);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch move requests' });
  }
};

exports.createMoveRequest = async (req, res) => {
  try {
    const { error } = moveRequestSchema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });

    const newMoveRequest = await prisma.moveRequest.create({
      data: {
        unitId: req.body.unitId,
        reason: req.body.reason,
        status: req.body.status,
        societyId: req.user.societyId,
      },
    });
    res.json(newMoveRequest);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create move request' });
  }
};

exports.updateMoveRequest = async (req, res) => {
  try {
    const { error } = moveRequestSchema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });

    const updatedMoveRequest = await prisma.moveRequest.update({
      where: { id: req.params.id },
      data: {
        unitId: req.body.unitId,
        reason: req.body.reason,
        status: req.body.status,
      },
    });
    res.json(updatedMoveRequest);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update move request' });
  }
};

exports.deleteMoveRequest = async (req, res) => {
  try {
    const deletedMoveRequest = await prisma.moveRequest.delete({
      where: { id: req.params.id },
    });
    res.json(deletedMoveRequest);
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete move request' });
  }
};
