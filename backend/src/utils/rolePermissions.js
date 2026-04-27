// CHAIRMAN is an alias for PRAMUKH (same person, English vs Hindi label).
// Only PRAMUKH is stored/configured; UI shows "Chairman".
const CONFIGURABLE_ROLES = [
  'PRAMUKH', 'SECRETARY', 'MANAGER',
  'VICE_CHAIRMAN', 'ASSISTANT_SECRETARY',
  'TREASURER', 'ASSISTANT_TREASURER',
  'MEMBER', 'RESIDENT', 'WATCHMAN',
];

const ALL_FEATURES = [
  { key: 'dashboard',    label: 'Dashboard',      group: 'Main' },
  { key: 'units',        label: 'Units',          group: 'Main' },
  { key: 'members',      label: 'Members',        group: 'Main' },
  { key: 'bills',        label: 'Bills',          group: 'Finance' },
  { key: 'expenses',     label: 'Expenses',       group: 'Finance' },
  { key: 'expense_approval', label: 'Expense Approval', group: 'Finance' },
  { key: 'donations',    label: 'Donations',      group: 'Finance' },
  { key: 'balance_report', label: 'Balance Report', group: 'Finance' },
  { key: 'pending_dues', label: 'Pending Dues',   group: 'Finance' },
  { key: 'visitors',     label: 'Visitors',       group: 'Security' },
  { key: 'gate_passes',  label: 'Gate Passes',    group: 'Security' },
  { key: 'vehicles',     label: 'Vehicles',       group: 'Security' },
  { key: 'parking',      label: 'Parking',        group: 'Security' },
  { key: 'complaints',   label: 'Complaints',     group: 'Society' },
  { key: 'suggestions',  label: 'Suggestions',    group: 'Society' },
  { key: 'notices',      label: 'Notices',        group: 'Society' },
  { key: 'polls',        label: 'Polls',          group: 'Society' },
  { key: 'events',       label: 'Events',         group: 'Society' },
  { key: 'amenities',    label: 'Amenities',      group: 'Society' },
  { key: 'staff',        label: 'Staff',          group: 'Society' },
  { key: 'deliveries',   label: 'Deliveries',     group: 'Society' },
  { key: 'domestic_help', label: 'Domestic Help', group: 'Society' },
  { key: 'chat',         label: 'Messages',       group: 'More' },
  { key: 'notifications', label: 'Notifications', group: 'More' },
];

const FEATURE_KEYS = ALL_FEATURES.map((f) => f.key);

function buildDefaults() {
  const allEnabled = {};
  FEATURE_KEYS.forEach((k) => { allEnabled[k] = true; });

  return {
    PRAMUKH:              { ...allEnabled },
    SECRETARY:           { ...allEnabled },
    MANAGER:             { ...allEnabled },
    VICE_CHAIRMAN:       { ...allEnabled },
    ASSISTANT_SECRETARY: { ...allEnabled },
    TREASURER:           { ...allEnabled },
    ASSISTANT_TREASURER: { ...allEnabled },
    MEMBER: {
      dashboard: true, bills: true, complaints: true, suggestions: true,
      notices: true, polls: true, events: true, chat: true, notifications: true,
      visitors: true, gate_passes: true, deliveries: true, domestic_help: true,
      amenities: true, donations: true,
      units: false, members: false, expenses: false, expense_approval: false,
      balance_report: false, pending_dues: false, vehicles: false, parking: false, staff: false,
    },
    RESIDENT: {
      dashboard: true, bills: true, complaints: true, suggestions: true,
      notices: true, polls: true, events: true, chat: true, notifications: true,
      visitors: true, gate_passes: true, deliveries: true, domestic_help: true,
      amenities: true, donations: true,
      units: false, members: false, expenses: false, expense_approval: false,
      balance_report: false, pending_dues: false, vehicles: false, parking: false, staff: false,
    },
    WATCHMAN: {
      dashboard: true, visitors: true, gate_passes: true, parking: true,
      deliveries: true, domestic_help: true, notifications: true,
      units: false, members: false, bills: false, expenses: false, expense_approval: false,
      donations: false, balance_report: false, pending_dues: false,
      vehicles: false, complaints: false, suggestions: false, notices: false,
      polls: false, events: false, amenities: false, staff: false, chat: false,
    },
  };
}

function resolveRoleFeatureAllowed({ rolePermissions, role, featureKey }) {
  // CHAIRMAN is an alias for PRAMUKH — resolve to the same permissions.
  const effectiveRole = role === 'CHAIRMAN' ? 'PRAMUKH' : role;
  const defaults = buildDefaults();
  const roleDefaults = defaults[effectiveRole] || {};
  const saved = (rolePermissions && (rolePermissions[effectiveRole] || rolePermissions[role]))
    ? (rolePermissions[effectiveRole] || rolePermissions[role])
    : {};
  const merged = { ...roleDefaults, ...saved };
  return merged[featureKey] === true;
}

module.exports = {
  CONFIGURABLE_ROLES,
  ALL_FEATURES,
  FEATURE_KEYS,
  buildDefaults,
  resolveRoleFeatureAllowed,
};

