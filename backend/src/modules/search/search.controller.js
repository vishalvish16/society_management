const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

function safeStr(v) {
  return (v ?? '').toString().trim();
}

function containsWhere(fields, q) {
  // Prisma "contains" is case-sensitive depending on collation; use mode: 'insensitive'
  // Only use on String columns — never on enums (Prisma will throw at runtime).
  return fields.map((f) => ({ [f]: { contains: q, mode: 'insensitive' } }));
}

exports.search = async (req, res) => {
  try {
    const q = safeStr(req.query.q);
    if (!q || q.length < 2) {
      return sendSuccess(res, { q, results: [] });
    }

    const { societyId, role } = req.user || {};
    if (role !== 'SUPER_ADMIN' && !societyId) {
      return sendError(res, 'No society assigned', 400);
    }

    // Limits per entity to keep search fast.
    const limit = Math.min(Number(req.query.limit || 5), 10);

    const isWatchman = role === 'WATCHMAN';
    const results = [];

    // ── Members (users) ───────────────────────────────────────────────
    // WATCHMAN: can search members only (for identity verification at gate)
    if (role !== 'SUPER_ADMIN') {
      const users = await prisma.user.findMany({
        where: {
          societyId,
          deletedAt: null,
          OR: [
            ...containsWhere(['name', 'phone', 'email'], q),
            {
              unitResidents: {
                some: {
                  unit: { fullCode: { contains: q, mode: 'insensitive' } },
                },
              },
            },
          ],
        },
        select: {
          id: true,
          name: true,
          phone: true,
          role: true,
          unitResidents: {
            take: 1,
            select: { unit: { select: { fullCode: true } } },
          },
        },
        take: limit,
        orderBy: { createdAt: 'desc' },
      });

      for (const u of users) {
        const unitCode = u.unitResidents?.[0]?.unit?.fullCode || '';
        results.push({
          type: 'member',
          id: u.id,
          title: u.name || 'Member',
          subtitle: `${u.role || ''}${unitCode ? ` · ${unitCode}` : ''}${u.phone ? ` · ${u.phone}` : ''}`.trim(),
          route: isWatchman ? '' : `/members?focusId=${encodeURIComponent(u.id)}`,
        });
      }
    }

    // ── Units ─────────────────────────────────────────────────────────
    if (role !== 'SUPER_ADMIN' && !isWatchman) {
      const units = await prisma.unit.findMany({
        where: {
          societyId,
          deletedAt: null,
          OR: [
            { fullCode: { contains: q, mode: 'insensitive' } },
            { unitNumber: { contains: q, mode: 'insensitive' } },
            { subUnit: { contains: q, mode: 'insensitive' } },
            { wing: { contains: q, mode: 'insensitive' } },
          ],
        },
        select: { id: true, fullCode: true, status: true, wing: true, floor: true },
        take: limit,
        orderBy: { createdAt: 'desc' },
      });

      for (const u of units) {
        results.push({
          type: 'unit',
          id: u.id,
          title: u.fullCode || 'Unit',
          subtitle: `${u.status || ''}${u.wing ? ` · Wing ${u.wing}` : ''}${u.floor != null ? ` · Floor ${u.floor}` : ''}`.trim(),
          route: `/units?focusId=${encodeURIComponent(u.id)}`,
        });
      }
    }

    // ── Complaints ────────────────────────────────────────────────────
    if (role !== 'SUPER_ADMIN' && !isWatchman) {
      const complaints = await prisma.complaint.findMany({
        where: {
          societyId,
          OR: [
            // category is ComplaintCategory enum — cannot use "contains"
            ...containsWhere(['title', 'description'], q),
            { unit: { fullCode: { contains: q, mode: 'insensitive' } } },
          ],
        },
        select: { id: true, title: true, status: true, priority: true, createdAt: true },
        take: limit,
        orderBy: { createdAt: 'desc' },
      });
      for (const c of complaints) {
        results.push({
          type: 'complaint',
          id: c.id,
          title: c.title || 'Complaint',
          subtitle: `${c.status || ''}${c.priority ? ` · ${c.priority}` : ''}`.trim(),
          route: `/complaints?focusId=${encodeURIComponent(c.id)}`,
        });
      }
    }

    // ── Suggestions ───────────────────────────────────────────────────
    if (role !== 'SUPER_ADMIN' && !isWatchman) {
      const suggestions = await prisma.suggestion.findMany({
        where: {
          societyId,
          OR: [
            ...containsWhere(['title', 'description'], q),
            { unit: { fullCode: { contains: q, mode: 'insensitive' } } },
          ],
        },
        select: { id: true, title: true, status: true, priority: true, createdAt: true },
        take: limit,
        orderBy: { createdAt: 'desc' },
      });
      for (const s of suggestions) {
        results.push({
          type: 'suggestion',
          id: s.id,
          title: s.title || 'Suggestion',
          subtitle: `${s.status || ''}${s.priority ? ` · ${s.priority}` : ''}`.trim(),
          route: `/suggestions?focusId=${encodeURIComponent(s.id)}`,
        });
      }
    }

    // ── Bills ─────────────────────────────────────────────────────────
    if (role !== 'SUPER_ADMIN' && !isWatchman) {
      const bills = await prisma.maintenanceBill.findMany({
        where: {
          societyId,
          deletedAt: null,
          OR: [
            // status is BillStatus enum — cannot use "contains"
            ...containsWhere(['title', 'description', 'category'], q),
            { unit: { fullCode: { contains: q, mode: 'insensitive' } } },
            { unit: { unitNumber: { contains: q, mode: 'insensitive' } } },
            { unit: { subUnit: { contains: q, mode: 'insensitive' } } },
          ],
        },
        select: {
          id: true,
          title: true,
          status: true,
          billingMonth: true,
          unit: { select: { fullCode: true } },
        },
        take: limit,
        orderBy: { createdAt: 'desc' },
      });
      for (const b of bills) {
        const unitCode = b.unit?.fullCode || '';
        const month = b.billingMonth ? new Date(b.billingMonth).toISOString().slice(0, 7) : '';
        results.push({
          type: 'bill',
          id: b.id,
          title: b.title || (unitCode ? `Bill · ${unitCode}` : 'Bill'),
          subtitle: `${b.status || ''}${unitCode ? ` · ${unitCode}` : ''}${month ? ` · ${month}` : ''}`.trim(),
          // BillAuditLogs supports billId query param and gives a “record” view.
          route: `/bills/audit-logs?billId=${encodeURIComponent(b.id)}`,
        });
      }
    }

    // De-dup by type+id and keep a stable order (members, units, complaints, bills)
    const seen = new Set();
    const uniq = [];
    for (const r of results) {
      const k = `${r.type}:${r.id}`;
      if (seen.has(k)) continue;
      seen.add(k);
      uniq.push(r);
    }

    return sendSuccess(res, { q, results: uniq.slice(0, 30) });
  } catch (err) {
    console.error('Search error:', err.message, err.stack?.split('\n').slice(0, 4).join(' | '));
    return sendError(res, 'Failed to search', 500);
  }
};

