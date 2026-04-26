const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

const VALID_CATEGORIES = ['GENERAL', 'PARKING', 'NOISE', 'PETS', 'MAINTENANCE', 'SECURITY', 'OTHER'];

const getRules = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { category, active } = req.query;

    const where = { societyId };
    if (category) where.category = category.toUpperCase();
    if (active !== undefined) where.isActive = active === 'true';

    const rules = await prisma.societyRule.findMany({
      where,
      include: {
        createdBy: { select: { name: true } },
      },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });

    return sendSuccess(res, rules, 'Rules retrieved');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const getRuleById = async (req, res) => {
  try {
    const { societyId } = req.user;
    const rule = await prisma.societyRule.findUnique({
      where: { id: req.params.id },
      include: { createdBy: { select: { name: true } } },
    });
    if (!rule || rule.societyId !== societyId) return sendError(res, 'Rule not found', 404);
    return sendSuccess(res, rule);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const createRule = async (req, res) => {
  try {
    const { societyId, id: createdById } = req.user;
    const { title, description, category, sortOrder } = req.body;

    if (!title || title.trim().length < 3) return sendError(res, 'Title is required (min 3 characters)', 400);

    const cat = (category || 'GENERAL').toUpperCase();
    if (!VALID_CATEGORIES.includes(cat)) {
      return sendError(res, `Invalid category. Must be one of: ${VALID_CATEGORIES.join(', ')}`, 400);
    }

    const rule = await prisma.societyRule.create({
      data: {
        societyId,
        createdById,
        title: title.trim(),
        description: description?.trim() || null,
        category: cat,
        sortOrder: sortOrder ?? 0,
      },
      include: { createdBy: { select: { name: true } } },
    });

    return sendSuccess(res, rule, 'Rule created', 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const updateRule = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const { title, description, category, sortOrder, isActive } = req.body;

    const rule = await prisma.societyRule.findUnique({ where: { id } });
    if (!rule || rule.societyId !== societyId) return sendError(res, 'Rule not found', 404);

    const updateData = {};
    if (title !== undefined) {
      if (title.trim().length < 3) return sendError(res, 'Title must be at least 3 characters', 400);
      updateData.title = title.trim();
    }
    if (description !== undefined) updateData.description = description?.trim() || null;
    if (category !== undefined) {
      const cat = category.toUpperCase();
      if (!VALID_CATEGORIES.includes(cat)) {
        return sendError(res, `Invalid category. Must be one of: ${VALID_CATEGORIES.join(', ')}`, 400);
      }
      updateData.category = cat;
    }
    if (sortOrder !== undefined) updateData.sortOrder = sortOrder;
    if (isActive !== undefined) updateData.isActive = isActive;

    const updated = await prisma.societyRule.update({
      where: { id },
      data: updateData,
      include: { createdBy: { select: { name: true } } },
    });

    return sendSuccess(res, updated, 'Rule updated');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const deleteRule = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { id } = req.params;
    const rule = await prisma.societyRule.findUnique({ where: { id } });
    if (!rule || rule.societyId !== societyId) return sendError(res, 'Rule not found', 404);
    await prisma.societyRule.delete({ where: { id } });
    return sendSuccess(res, null, 'Rule deleted');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

const reorderRules = async (req, res) => {
  try {
    const { societyId } = req.user;
    const { orderedIds } = req.body;

    if (!Array.isArray(orderedIds) || orderedIds.length === 0) {
      return sendError(res, 'orderedIds array is required', 400);
    }

    const rules = await prisma.societyRule.findMany({
      where: { id: { in: orderedIds }, societyId },
      select: { id: true },
    });
    const validIds = new Set(rules.map((r) => r.id));

    const updates = orderedIds
      .filter((id) => validIds.has(id))
      .map((id, index) =>
        prisma.societyRule.update({ where: { id }, data: { sortOrder: index } })
      );

    await prisma.$transaction(updates);
    return sendSuccess(res, null, 'Rules reordered');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

module.exports = { getRules, getRuleById, createRule, updateRule, deleteRule, reorderRules };
