const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const Joi = require('joi');

const vehicleSchema = Joi.object({
  plateNumber: Joi.string().required(),
  unitId: Joi.number().required(),
});

exports.getAllVehicles = async (req, res) => {
  try {
    const vehicles = await prisma.vehicle.findMany({
      where: { societyId: req.user.societyId },
    });
    res.json(vehicles);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch vehicles' });
  }
};

exports.createVehicle = async (req, res) => {
  try {
    const { error } = vehicleSchema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });

    const newVehicle = await prisma.vehicle.create({
      data: {
        plateNumber: req.body.plateNumber,
        unitId: req.body.unitId,
        societyId: req.user.societyId,
      },
    });
    res.json(newVehicle);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create vehicle' });
  }
};

exports.updateVehicle = async (req, res) => {
  try {
    const { error } = vehicleSchema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });

    const updatedVehicle = await prisma.vehicle.update({
      where: { id: req.params.id },
      data: {
        plateNumber: req.body.plateNumber,
        unitId: req.body.unitId,
      },
    });
    res.json(updatedVehicle);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update vehicle' });
  }
};

exports.deleteVehicle = async (req, res) => {
  try {
    const deletedVehicle = await prisma.vehicle.delete({
      where: { id: req.params.id },
    });
    res.json(deletedVehicle);
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete vehicle' });
  }
};
