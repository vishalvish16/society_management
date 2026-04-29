const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');
const { resolveRoleFeatureAllowed, buildDefaults } = require('../../utils/rolePermissions');

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

    // Load society's saved role permissions so we can respect admin-toggled feature access.
    let rolePermissions = {};
    if (societyId) {
      const society = await prisma.society.findUnique({
        where: { id: societyId },
        select: { settings: true },
      });
      rolePermissions = society?.settings?.rolePermissions || {};
    }

    // Helper: returns true if this user's role has the given feature enabled.
    const canAccess = (featureKey) => {
      if (role === 'SUPER_ADMIN') return true;
      return resolveRoleFeatureAllowed({ rolePermissions, role, featureKey });
    };

    // ── Members (users) ───────────────────────────────────────────────
    if (canAccess('members')) {
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
          route: `/members?focusId=${encodeURIComponent(u.id)}`,
        });
      }
    }

    // ── Vehicles ──────────────────────────────────────────────────────
    if (canAccess('vehicles')) {
      const vehicles = await prisma.vehicle.findMany({
        where: {
          societyId,
          isActive: true,
          OR: [
            ...containsWhere(['numberPlate', 'brand', 'model', 'colour'], q),
            { unit: { fullCode: { contains: q, mode: 'insensitive' } } },
          ],
        },
        select: {
          id: true,
          numberPlate: true,
          type: true,
          brand: true,
          model: true,
          colour: true,
          unit: { select: { fullCode: true } },
        },
        take: limit,
        orderBy: { createdAt: 'desc' },
      });

      for (const v of vehicles) {
        const unitCode = v.unit?.fullCode || '';
        const meta = [v.type, unitCode].filter(Boolean).join(' · ');
        results.push({
          type: 'vehicle',
          id: v.id,
          title: v.numberPlate || 'Vehicle',
          subtitle: `${meta}${meta && (v.brand || v.model || v.colour) ? ' · ' : ''}${[v.brand, v.model, v.colour].filter(Boolean).join(' ')}`.trim(),
          route: `/vehicles?plate=${encodeURIComponent(v.numberPlate || '')}`,
        });
      }
    }

    // ── Units ─────────────────────────────────────────────────────────
    if (canAccess('units')) {
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

    // ── Visitors ──────────────────────────────────────────────────────
    if (canAccess('visitors')) {
      const visitors = await prisma.visitor.findMany({
        where: {
          societyId,
          OR: [
            ...containsWhere(['visitorName', 'visitorPhone', 'visitorEmail', 'description'], q),
            { unit: { fullCode: { contains: q, mode: 'insensitive' } } },
          ],
        },
        select: {
          id: true,
          visitorName: true,
          visitorPhone: true,
          status: true,
          unit: { select: { fullCode: true } },
          createdAt: true,
        },
        take: limit,
        orderBy: { createdAt: 'desc' },
      });

      for (const v of visitors) {
        const unitCode = v.unit?.fullCode || '';
        results.push({
          type: 'visitor',
          id: v.id,
          title: v.visitorName || 'Visitor',
          subtitle: `${unitCode ? `Unit ${unitCode}` : ''}${v.visitorPhone ? `${unitCode ? ' · ' : ''}${v.visitorPhone}` : ''}${v.status ? ` · ${v.status}` : ''}`.trim(),
          route: '/visitors',
        });
      }
    }

    // ── Deliveries ────────────────────────────────────────────────────
    if (canAccess('deliveries')) {
      const deliveries = await prisma.delivery.findMany({
        where: {
          societyId,
          OR: [
            ...containsWhere(['agentName', 'company', 'description'], q),
            { unit: { fullCode: { contains: q, mode: 'insensitive' } } },
          ],
        },
        select: {
          id: true,
          agentName: true,
          company: true,
          status: true,
          unit: { select: { fullCode: true } },
          createdAt: true,
        },
        take: limit,
        orderBy: { createdAt: 'desc' },
      });

      for (const d of deliveries) {
        const unitCode = d.unit?.fullCode || '';
        results.push({
          type: 'delivery',
          id: d.id,
          title: d.company ? `${d.company}` : (d.agentName || 'Delivery'),
          subtitle: `${unitCode ? `Unit ${unitCode}` : ''}${d.status ? `${unitCode ? ' · ' : ''}${d.status}` : ''}${d.agentName ? ` · ${d.agentName}` : ''}`.trim(),
          route: '/deliveries',
        });
      }
    }

    // ── Domestic Help ────────────────────────────────────────────────
    if (canAccess('domestic_help')) {
      const helps = await prisma.domesticHelp.findMany({
        where: {
          societyId,
          OR: [
            ...containsWhere(['name', 'phone', 'notes', 'entryCode'], q),
            { unit: { fullCode: { contains: q, mode: 'insensitive' } } },
          ],
        },
        select: {
          id: true,
          name: true,
          phone: true,
          type: true,
          status: true,
          unit: { select: { fullCode: true } },
          createdAt: true,
        },
        take: limit,
        orderBy: { createdAt: 'desc' },
      });

      for (const h of helps) {
        const unitCode = h.unit?.fullCode || '';
        results.push({
          type: 'domestic_help',
          id: h.id,
          title: h.name || 'Domestic Help',
          subtitle: `${h.type || ''}${unitCode ? ` · ${unitCode}` : ''}${h.phone ? ` · ${h.phone}` : ''}${h.status ? ` · ${h.status}` : ''}`.trim(),
          route: '/domestichelp',
        });
      }
    }

    // ── Staff ─────────────────────────────────────────────────────────
    if (canAccess('staff')) {
      const staff = await prisma.staff.findMany({
        where: {
          societyId,
          isActive: true,
          OR: [
            ...containsWhere(['name', 'role', 'phone'], q),
          ],
        },
        select: {
          id: true,
          name: true,
          role: true,
          phone: true,
          shift: true,
          gate: { select: { name: true } },
          createdAt: true,
        },
        take: limit,
        orderBy: { createdAt: 'desc' },
      });

      for (const s of staff) {
        const gateName = s.gate?.name || '';
        results.push({
          type: 'staff',
          id: s.id,
          title: s.name || 'Staff',
          subtitle: `${s.role || ''}${gateName ? ` · ${gateName}` : ''}${s.shift ? ` · ${s.shift}` : ''}${s.phone ? ` · ${s.phone}` : ''}`.trim(),
          route: '/staff',
        });
      }
    }

    // ── Assets ────────────────────────────────────────────────────────
    if (!isWatchman && role !== 'SUPER_ADMIN') {
      const assets = await prisma.asset.findMany({
        where: {
          societyId,
          OR: [
            ...containsWhere(['name', 'category', 'assetTag', 'description', 'location', 'vendor', 'serialNumber'], q),
            { unit: { fullCode: { contains: q, mode: 'insensitive' } } },
          ],
        },
        select: {
          id: true,
          name: true,
          category: true,
          assetTag: true,
          status: true,
          unit: { select: { fullCode: true } },
          createdAt: true,
        },
        take: limit,
        orderBy: { createdAt: 'desc' },
      });

      for (const a of assets) {
        const unitCode = a.unit?.fullCode || '';
        results.push({
          type: 'asset',
          id: a.id,
          title: a.name || 'Asset',
          subtitle: `${a.category || ''}${a.assetTag ? ` · ${a.assetTag}` : ''}${unitCode ? ` · ${unitCode}` : ''}${a.status ? ` · ${a.status}` : ''}`.trim(),
          route: '/assets',
        });
      }
    }

    // ── Complaints ────────────────────────────────────────────────────
    if (canAccess('complaints')) {
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
    if (canAccess('suggestions')) {
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
    if (canAccess('bills')) {
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

    // ── Donations & Campaigns ─────────────────────────────────────────
    if (!isWatchman && canAccess('donations')) {
      const campaigns = await prisma.donationCampaign.findMany({
        where: {
          societyId,
          OR: [
            ...containsWhere(['title', 'description'], q),
          ],
        },
        select: {
          id: true,
          title: true,
          isActive: true,
          startDate: true,
          endDate: true,
        },
        take: limit,
        orderBy: { createdAt: 'desc' },
      });

      for (const c of campaigns) {
        const active = c.isActive ? 'Active' : 'Closed';
        const start = c.startDate ? new Date(c.startDate).toISOString().slice(0, 10) : '';
        results.push({
          type: 'donation_campaign',
          id: c.id,
          title: c.title || 'Donation Campaign',
          subtitle: `${active}${start ? ` · From ${start}` : ''}`.trim(),
          route: '/donations',
        });
      }

      const donations = await prisma.donation.findMany({
        where: {
          societyId,
          OR: [
            ...containsWhere(['note'], q),
            {
              donor: {
                OR: [
                  ...containsWhere(['name', 'phone', 'email'], q),
                ],
              },
            },
            { campaign: { title: { contains: q, mode: 'insensitive' } } },
          ],
        },
        select: {
          id: true,
          amount: true,
          paymentMethod: true,
          paidAt: true,
          note: true,
          donor: { select: { id: true, name: true, phone: true } },
          campaign: { select: { id: true, title: true } },
        },
        take: limit,
        orderBy: { paidAt: 'desc' },
      });

      for (const d of donations) {
        const donorName = d.donor?.name || 'Donor';
        const donorPhone = d.donor?.phone || '';
        const campaignTitle = d.campaign?.title || '';
        const amt = d.amount != null ? Number(d.amount) : 0;
        const date = d.paidAt ? new Date(d.paidAt).toISOString().slice(0, 10) : '';
        const parts = [
          campaignTitle,
          donorPhone,
          date,
          amt ? `₹${amt}` : '',
        ].filter(Boolean);
        results.push({
          type: 'donation',
          id: d.id,
          title: donorName,
          subtitle: parts.join(' · '),
          route: '/donations',
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

