const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const Joi = require('joi');

const deliverySchema = Joi.object({
  unitId: Joi.number().required(),
  description: Joi.string().required(),
  status: Joi.string().valid('pending', 'collected').required(),
});

exports.getAllDeliveries = async (req, res) => {
  try {
    const deliveries = await prisma.delivery.findMany({
      where: { societyId: req.user.societyId },
    });
    res.json(deliveries);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch deliveries' });
  }
};

exports.createDelivery = async (req, res) => {
  try {
    const { error } = deliverySchema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });

    const newDelivery = await prisma.delivery.create({
      data: {
        unitId: req.body.unitId,
        description: req.body.description,
        status: req.body.status,
        societyId: req.user.societyId,
      },
    });
    res.json(newDelivery);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create delivery' });
  }
};

exports.updateDelivery = async (req, res) => {
  try {
    const { error } = deliverySchema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });

    const updatedDelivery = await prisma.delivery.update({
      where: { id: req.params.id },
      data: {
        unitId: req.body.unitId,
        description: req.body.description,
        status: req.body.status,
      },
    });
    res.json(updatedDelivery);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update delivery' });
  }
};

exports.deleteDelivery = async (req, res) => {
  try {
    const deletedDelivery = await prisma.delivery.delete({
      where: { id: req.params.id },
    });
    res.json(deletedDelivery);
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete delivery' });
  }
};
