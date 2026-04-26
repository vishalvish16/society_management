const rentalsService = require('./rentals.service');
const { sendSuccess, sendError } = require('../../utils/response');

async function listRentals(req, res) {
  try {
    const result = await rentalsService.listRentals(req.user.societyId, req.query);
    return sendSuccess(res, result, 'Rental records retrieved');
  } catch (error) {
    console.error('List rentals error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

async function getRental(req, res) {
  try {
    const record = await rentalsService.getRental(req.params.id, req.user.societyId);
    return sendSuccess(res, record, 'Rental record retrieved');
  } catch (error) {
    console.error('Get rental error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

function _parseDocTypes(body) {
  let docTypes = body.docTypes;
  if (typeof docTypes === 'string') {
    if (docTypes.includes(',')) {
      docTypes = docTypes.split(',').map((s) => s.trim());
    } else {
      try { docTypes = JSON.parse(docTypes); } catch { docTypes = [docTypes]; }
    }
  }
  return Array.isArray(docTypes) ? docTypes : [];
}

async function createRental(req, res) {
  try {
    const { unitId, tenantName, tenantPhone, agreementStartDate } = req.body;

    if (!unitId) return sendError(res, 'Unit is required', 400);
    if (!tenantName) return sendError(res, 'Tenant name is required', 400);
    if (!tenantPhone) return sendError(res, 'Tenant phone is required', 400);
    if (!agreementStartDate) return sendError(res, 'Agreement start date is required', 400);

    const files = req.files || [];
    const docTypes = _parseDocTypes(req.body);

    const hasAadhaar = docTypes.includes('AADHAAR');
    const hasAgreement = docTypes.includes('RENT_AGREEMENT');

    if (!hasAadhaar) return sendError(res, 'Aadhaar card document is mandatory', 400);
    if (!hasAgreement) return sendError(res, 'Rent agreement document is mandatory', 400);

    const fileData = files.map((f, i) => ({
      docType: docTypes[i] || 'OTHER',
      fileName: f.originalname,
      fileType: f.mimetype,
      fileSize: f.size,
      fileUrl: `/uploads/rentals/${f.filename}`,
    }));

    const data = { ...req.body };
    delete data.docTypes;
    delete data.documents;

    let membersData = [];
    if (data.members) {
      try {
        membersData = typeof data.members === 'string' ? JSON.parse(data.members) : data.members;
      } catch { membersData = []; }
      delete data.members;
    }

    const record = await rentalsService.createRental(req.user.societyId, data, fileData, membersData);
    return sendSuccess(res, record, 'Rental record created', 201);
  } catch (error) {
    console.error('Create rental error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

async function updateRental(req, res) {
  try {
    const files = req.files || [];
    const docTypes = _parseDocTypes(req.body);

    const fileData = files.map((f, i) => ({
      docType: docTypes[i] || 'OTHER',
      fileName: f.originalname,
      fileType: f.mimetype,
      fileSize: f.size,
      fileUrl: `/uploads/rentals/${f.filename}`,
    }));

    const data = { ...req.body };
    delete data.docTypes;
    delete data.documents;

    const record = await rentalsService.updateRental(req.params.id, req.user.societyId, data, fileData);
    return sendSuccess(res, record, 'Rental record updated');
  } catch (error) {
    console.error('Update rental error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

async function endRental(req, res) {
  try {
    const record = await rentalsService.endRental(req.params.id, req.user.societyId);
    return sendSuccess(res, record, 'Rental ended successfully');
  } catch (error) {
    console.error('End rental error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

async function deleteRental(req, res) {
  try {
    await rentalsService.deleteRental(req.params.id, req.user.societyId);
    return sendSuccess(res, null, 'Rental record deleted');
  } catch (error) {
    console.error('Delete rental error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

async function deleteDocument(req, res) {
  try {
    await rentalsService.deleteDocument(req.params.id, req.params.docId, req.user.societyId);
    return sendSuccess(res, null, 'Document deleted');
  } catch (error) {
    console.error('Delete document error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

async function syncMembers(req, res) {
  try {
    const { members } = req.body;
    if (!Array.isArray(members)) return sendError(res, 'members must be an array', 400);

    for (const m of members) {
      if (!m.name || !m.name.trim()) return sendError(res, 'Each member must have a name', 400);
      if (!m.relation) return sendError(res, 'Each member must have a relation (SELF, SPOUSE, CHILD, etc.)', 400);
    }

    const record = await rentalsService.syncMembers(req.params.id, req.user.societyId, members);
    return sendSuccess(res, record, 'Members updated');
  } catch (error) {
    console.error('Sync members error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

module.exports = { listRentals, getRental, createRental, updateRental, endRental, deleteRental, deleteDocument, syncMembers };
