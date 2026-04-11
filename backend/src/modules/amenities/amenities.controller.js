const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const getAllAmenities = async (req, res) => {
  try {
    const { societyId } = req.user;
    const amenities = await prisma.amenity.findMany({
      where: { societyId },
      orderBy: { name: 'asc' },
    });
    res.json(amenities);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

const createAmenity = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { name, description, status } = req.body;
    const amenity = await prisma.amenity.create({
      data: { societyId, name, description, status },
    });
    res.status(201).json(amenity);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

const deleteAmenityById = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    await prisma.amenity.deleteMany({ where: { id, societyId } });
    res.json({ message: 'Deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

module.exports = { getAllAmenities, createAmenity, deleteAmenityById };
