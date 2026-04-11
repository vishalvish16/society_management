# SOCIETY MANAGER — MASTER AGENT PROMPT v3.0
# Token-optimised. Design system integrated. 55 features. Run this once — build everything.

---

## AGENT IDENTITY

You are an autonomous full-stack engineer. Build the complete Society Manager SaaS platform from scratch. Write every file, run every command, fix every error. Never ask for clarification — make decisions, document them in DECISIONS.md.

Two codebases:
1. `society-manager-backend` — Node.js 20, Express 5, Prisma, PostgreSQL, Redis
2. `society-manager-flutter` — Flutter 3, Android + iOS + Web

---

## 8 NON-NEGOTIABLE RULES

1. **Verify** — after every file, run it. After every API, test with curl/Jest. After every screen, run `flutter analyze`. Fix before moving on.
2. **Fix autonomously** — if stuck after 3 attempts, write to ERRORS.md and continue.
3. **Tests alongside code** — Jest+Supertest for every backend module, widget test for every Flutter screen. Target 80% coverage.
4. **Document decisions** — write to DECISIONS.md with reasoning.
5. **No hardcoded secrets** — everything in .env. .env in .gitignore.
6. **Cron idempotency** — always check if record exists before creating.
7. **society_id on every query** — no exceptions. Cross-society leak = critical bug.
8. **Design system only** — never use raw Colors.*, TextStyle(), or hardcoded hex in Flutter. Always AppColors.*, AppTextStyles.*.

---

## PHASE 0: SETUP

### 0.1 Backend
```bash
mkdir society-manager-backend && cd society-manager-backend
npm init -y
npm install express@5 prisma @prisma/client jsonwebtoken bcryptjs zod ioredis qrcode \
  @aws-sdk/client-s3 @aws-sdk/s3-request-presigner twilio firebase-admin node-cron \
  pdfkit multer helmet express-rate-limit morgan cors uuid csv-parse razorpay sharp \
  nodemailer crypto
npm install -D jest supertest eslint prettier nodemon
npx prisma init
git init && echo "node_modules\n.env\n*.pem\ndist" > .gitignore
```

### 0.2 Flutter
```bash
flutter create society_manager --org com.societymanager --platforms android,ios,web
cd society_manager
```

pubspec.yaml dependencies:
```yaml
  go_router: ^14.0.0
  flutter_riverpod: ^2.5.0
  dio: ^5.4.0
  flutter_secure_storage: ^9.0.0
  mobile_scanner: ^5.0.0
  firebase_core: ^3.0.0
  firebase_messaging: ^15.0.0
  fl_chart: ^0.68.0
  file_picker: ^8.0.0
  flutter_pdfview: ^1.3.0
  cached_network_image: ^3.3.0
  intl: ^0.19.0
  hive_flutter: ^1.1.0
  shimmer: ^3.0.0
  razorpay_flutter: ^1.3.0
  share_plus: ^9.0.0
  local_auth: ^2.2.0
  image_picker: ^1.1.0
  csv: ^6.0.0
  google_fonts: ^6.2.1
  flutter_animate: ^4.5.0
  table_calendar: ^3.1.0
  timeline_tile: ^2.0.0
  qr_flutter: ^4.1.0
  dropdown_search: ^6.0.0
  pinput: ^5.0.0
```

---

## PHASE 1: DATABASE SCHEMA

### 1.1 Enums
```prisma
enum PlanName          { basic standard premium }
enum SocietyStatus     { active suspended deleted }
enum UserRole          { super_admin pramukh secretary resident watchman }
enum UnitStatus        { occupied vacant renovation }
enum BillStatus        { pending partial paid overdue }
enum PaymentMethod     { cash bank upi online razorpay }
enum ExpenseCategory   { maintenance utilities events security other }
enum ExpenseStatus     { pending approved rejected }
enum VisitorStatus     { pending valid used expired }
enum ScanResult        { valid invalid expired }
enum ComplaintStatus   { open assigned in_progress resolved closed }
enum ComplaintCategory { plumbing electrical lift parking cleaning security other }
enum AttendanceStatus  { present absent half_day leave }
enum NotificationType  { bill payment expense visitor announcement manual complaint delivery domestic_help move_in_out amenity gate_pass }
enum DomesticHelpType  { maid cook driver nurse sweeper gardener other }
enum DomesticHelpStatus { active suspended removed }
enum DeliveryStatus    { pending allowed denied collected left_at_gate }
enum MoveRequestType   { move_in move_out }
enum MoveRequestStatus { pending dues_cleared approved rejected completed }
enum ResidentType      { owner tenant }
enum VehicleType       { car two_wheeler cycle other }
enum AmenityStatus     { active inactive under_maintenance }
enum BookingStatus     { pending confirmed cancelled completed }
enum GatePassStatus    { active used expired cancelled }
```

### 1.2 Models

```prisma
model Plan {
  id             String    @id @default(uuid())
  name           PlanName  @unique
  displayName    String
  priceMonthly   Decimal   @db.Decimal(10,2)
  priceYearly    Decimal   @db.Decimal(10,2)
  maxUnits       Int       // -1 = unlimited
  maxSecretaries Int       // -1 = unlimited
  features       Json      // { visitor_qr, expense_approval, attachments_count, whatsapp, pdf_receipts }
  isActive       Boolean   @default(true)
  societies      Society[]
  createdAt      DateTime  @default(now())
  updatedAt      DateTime  @updatedAt
}

model Society {
  id              String        @id @default(uuid())
  name            String
  address         String?
  city            String?
  logoUrl         String?
  contactEmail    String?
  contactPhone    String?
  planId          String
  plan            Plan          @relation(fields: [planId], references: [id])
  planStartDate   DateTime
  planRenewalDate DateTime
  status          SocietyStatus @default(active)
  settings        Json?
  // settings shape: { late_fee_type, late_fee_amount, due_day, qr_expiry_mins,
  //                   unit_prefix, gstin, gst_rate, gst_applicable,
  //                   amenity_approval_required, delivery_timeout_mins }
  createdById     String?
  createdAt       DateTime      @default(now())
  updatedAt       DateTime      @updatedAt
  users           User[]
  units           Unit[]
  expenses        Expense[]
  visitors        Visitor[]
  notifications   Notification[]
  notices         Notice[]
  complaints      Complaint[]
  staff           Staff[]
  subscriptionPayments SubscriptionPayment[]
  domesticHelps   DomesticHelp[]
  deliveries      Delivery[]
  vehicles        Vehicle[]
  parkingSlots    ParkingSlot[]
  moveRequests    MoveRequest[]
  amenities       Amenity[]
  amenityBookings AmenityBooking[]
  gatePasses      GatePass[]
}

model User {
  id           String    @id @default(uuid())
  societyId    String?   // NULL for super_admin
  society      Society?  @relation(fields: [societyId], references: [id])
  role         UserRole
  name         String
  email        String?   @unique
  phone        String
  passwordHash String
  fcmToken     String?
  isActive     Boolean   @default(true)
  createdById  String?
  deletedAt    DateTime?
  createdAt    DateTime  @default(now())
  updatedAt    DateTime  @updatedAt
  unitResidents       UnitResident[]
  bills               MaintenanceBill[]
  raisedComplaints    Complaint[]       @relation("RaisedBy")
  assignedComplaints  Complaint[]       @relation("AssignedTo")
  markedAttendance    StaffAttendance[]
  refreshTokens       RefreshToken[]
}

model RefreshToken {
  id        String   @id @default(uuid())
  userId    String
  user      User     @relation(fields: [userId], references: [id])
  token     String   @unique
  expiresAt DateTime
  createdAt DateTime @default(now())
}

model Unit {
  id         String     @id @default(uuid())
  societyId  String
  society    Society    @relation(fields: [societyId], references: [id])
  wing       String?
  floor      Int?
  unitNumber String
  subUnit    String?
  fullCode   String     // auto-generated: see fullCodeGenerator
  status     UnitStatus @default(occupied)
  areaSqft   Decimal?   @db.Decimal(8,2)
  notes      String?
  createdAt  DateTime   @default(now())
  updatedAt  DateTime   @updatedAt
  residents       UnitResident[]
  bills           MaintenanceBill[]
  visitors        Visitor[]
  complaints      Complaint[]
  domesticHelps   DomesticHelp[]
  deliveries      Delivery[]
  vehicles        Vehicle[]
  parkingSlots    ParkingSlot[]
  moveRequests    MoveRequest[]
  amenityBookings AmenityBooking[]
  gatePasses      GatePass[]
  @@unique([societyId, fullCode])
  @@index([societyId])
}

model UnitResident {
  id          String    @id @default(uuid())
  unitId      String
  unit        Unit      @relation(fields: [unitId], references: [id])
  userId      String
  user        User      @relation(fields: [userId], references: [id])
  isOwner     Boolean   @default(false)
  moveInDate  DateTime?
  moveOutDate DateTime?
  createdAt   DateTime  @default(now())
  @@unique([unitId, userId])
}

model MaintenanceBill {
  id               String         @id @default(uuid())
  societyId        String
  unitId           String
  unit             Unit           @relation(fields: [unitId], references: [id])
  billingMonth     DateTime
  amount           Decimal        @db.Decimal(10,2)
  lateFee          Decimal        @default(0) @db.Decimal(10,2)
  totalDue         Decimal        @db.Decimal(10,2)
  status           BillStatus     @default(pending)
  dueDate          DateTime
  paidAmount       Decimal        @default(0) @db.Decimal(10,2)
  paidAt           DateTime?
  paidById         String?
  paidBy           User?          @relation(fields: [paidById], references: [id])
  paymentMethod    PaymentMethod?
  razorpayOrderId  String?
  razorpayPaymentId String?
  receiptUrl       String?
  notes            String?
  gstAmount        Decimal        @default(0) @db.Decimal(10,2)
  createdAt        DateTime       @default(now())
  updatedAt        DateTime       @updatedAt
  @@unique([unitId, billingMonth])
  @@index([societyId])
  @@index([unitId])
  @@index([status])
}

model Expense {
  id              String          @id @default(uuid())
  societyId       String
  society         Society         @relation(fields: [societyId], references: [id])
  submittedById   String
  category        ExpenseCategory
  title           String
  description     String?
  amount          Decimal         @db.Decimal(10,2)
  gstAmount       Decimal         @default(0) @db.Decimal(10,2)
  totalAmount     Decimal         @db.Decimal(10,2)
  expenseDate     DateTime
  status          ExpenseStatus   @default(pending)
  approvedById    String?
  approvedAt      DateTime?
  rejectionReason String?
  createdAt       DateTime        @default(now())
  updatedAt       DateTime        @updatedAt
  attachments     ExpenseAttachment[]
  @@index([societyId])
}

model ExpenseAttachment {
  id            String  @id @default(uuid())
  expenseId     String
  expense       Expense @relation(fields: [expenseId], references: [id])
  fileUrl       String
  fileName      String?
  fileType      String?
  fileSizeBytes Int?
  createdAt     DateTime @default(now())
}

model Visitor {
  id              String        @id @default(uuid())
  societyId       String
  society         Society       @relation(fields: [societyId], references: [id])
  unitId          String
  unit            Unit          @relation(fields: [unitId], references: [id])
  invitedById     String
  visitorName     String
  visitorPhone    String
  expectedArrival DateTime?
  noteForWatchman String?
  qrToken         String        @unique @default(uuid())
  qrExpiresAt     DateTime
  qrImageUrl      String?
  whatsappSentAt  DateTime?
  status          VisitorStatus @default(pending)
  createdAt       DateTime      @default(now())
  log             VisitorLog[]
  @@index([societyId])
  @@index([qrToken])
}

model VisitorLog {
  id          String     @id @default(uuid())
  visitorId   String
  visitor     Visitor    @relation(fields: [visitorId], references: [id])
  scannedById String
  scanResult  ScanResult
  scannedAt   DateTime   @default(now())
}

model Notification {
  id         String           @id @default(uuid())
  societyId  String
  society    Society          @relation(fields: [societyId], references: [id])
  targetType String           // unit | role | all
  targetId   String?
  title      String
  body       String
  type       NotificationType
  sentById   String?
  sentAt     DateTime         @default(now())
  reads      NotificationRead[]
  @@index([societyId])
}

model NotificationRead {
  id             String       @id @default(uuid())
  notificationId String
  notification   Notification @relation(fields: [notificationId], references: [id])
  userId         String
  readAt         DateTime     @default(now())
  @@unique([notificationId, userId])
}

model Notice {
  id          String   @id @default(uuid())
  societyId   String
  society     Society  @relation(fields: [societyId], references: [id])
  title       String
  body        String
  pinned      Boolean  @default(false)
  createdById String
  expiresAt   DateTime?
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  @@index([societyId])
}

model Complaint {
  id           String            @id @default(uuid())
  societyId    String
  society      Society           @relation(fields: [societyId], references: [id])
  unitId       String
  unit         Unit              @relation(fields: [unitId], references: [id])
  raisedById   String
  raisedBy     User              @relation("RaisedBy", fields: [raisedById], references: [id])
  category     ComplaintCategory
  title        String
  description  String?
  status       ComplaintStatus   @default(open)
  assignedToId String?
  assignedTo   User?             @relation("AssignedTo", fields: [assignedToId], references: [id])
  resolvedAt   DateTime?
  createdAt    DateTime          @default(now())
  updatedAt    DateTime          @updatedAt
  @@index([societyId])
  @@index([status])
}

model Staff {
  id          String    @id @default(uuid())
  societyId   String
  society     Society   @relation(fields: [societyId], references: [id])
  name        String
  role        String
  phone       String?
  salary      Decimal   @db.Decimal(10,2)
  joiningDate DateTime?
  isActive    Boolean   @default(true)
  createdAt   DateTime  @default(now())
  attendance  StaffAttendance[]
  @@index([societyId])
}

model StaffAttendance {
  id         String           @id @default(uuid())
  staffId    String
  staff      Staff            @relation(fields: [staffId], references: [id])
  date       DateTime         @db.Date
  status     AttendanceStatus
  markedById String
  markedBy   User             @relation(fields: [markedById], references: [id])
  markedAt   DateTime         @default(now())
  @@unique([staffId, date])
}

model SubscriptionPayment {
  id            String   @id @default(uuid())
  societyId     String
  society       Society  @relation(fields: [societyId], references: [id])
  planId        String
  amount        Decimal  @db.Decimal(10,2)
  periodStart   DateTime
  periodEnd     DateTime
  paymentMethod String?
  reference     String?
  recordedById  String?
  notes         String?
  createdAt     DateTime @default(now())
  @@index([societyId])
}

model RazorpayPayment {
  id        String   @id @default(uuid())
  billId    String
  orderId   String   @unique
  paymentId String?  @unique
  signature String?
  amount    Decimal  @db.Decimal(10,2)
  status    String   // created | paid | failed
  createdAt DateTime @default(now())
}

// ── HIGH PRIORITY FEATURE MODELS ─────────────────────────────────────────────

model DomesticHelp {
  id             String              @id @default(uuid())
  societyId      String
  society        Society             @relation(fields: [societyId], references: [id])
  unitId         String
  unit           Unit                @relation(fields: [unitId], references: [id])
  registeredById String
  name           String
  type           DomesticHelpType
  phone          String?
  photoUrl       String?
  entryCode      String              @unique  // 6-digit numeric
  status         DomesticHelpStatus  @default(active)
  allowedDays    Json?               // [1,2,3,4,5] weekdays allowed
  allowedFrom    String?             // "07:00"
  allowedTo      String?             // "21:00"
  notes          String?
  createdAt      DateTime            @default(now())
  updatedAt      DateTime            @updatedAt
  logs           DomesticHelpLog[]
  @@index([societyId])
  @@index([entryCode])
}

model DomesticHelpLog {
  id             String       @id @default(uuid())
  domesticHelpId String
  domesticHelp   DomesticHelp @relation(fields: [domesticHelpId], references: [id])
  unitId         String
  loggedById     String
  type           String       // entry | exit
  loggedAt       DateTime     @default(now())
  @@index([domesticHelpId])
}

model Delivery {
  id           String         @id @default(uuid())
  societyId    String
  society      Society        @relation(fields: [societyId], references: [id])
  unitId       String
  unit         Unit           @relation(fields: [unitId], references: [id])
  loggedById   String
  agentName    String
  company      String?
  description  String?
  status       DeliveryStatus @default(pending)
  notifiedAt   DateTime?
  respondedAt  DateTime?
  respondedBy  String?
  collectedAt  DateTime?
  photoUrl     String?
  createdAt    DateTime       @default(now())
  updatedAt    DateTime       @updatedAt
  @@index([societyId])
  @@index([status])
}

model Vehicle {
  id             String      @id @default(uuid())
  societyId      String
  society        Society     @relation(fields: [societyId], references: [id])
  unitId         String
  unit           Unit        @relation(fields: [unitId], references: [id])
  registeredById String
  type           VehicleType
  numberPlate    String
  brand          String?
  model          String?
  colour         String?
  isActive       Boolean     @default(true)
  createdAt      DateTime    @default(now())
  updatedAt      DateTime    @updatedAt
  @@unique([societyId, numberPlate])
  @@index([societyId])
}

model ParkingSlot {
  id         String   @id @default(uuid())
  societyId  String
  society    Society  @relation(fields: [societyId], references: [id])
  slotNumber String
  type       String   // covered | open | basement | visitor
  unitId     String?
  unit       Unit?    @relation(fields: [unitId], references: [id])
  isActive   Boolean  @default(true)
  notes      String?
  createdAt  DateTime @default(now())
  updatedAt  DateTime @updatedAt
  @@unique([societyId, slotNumber])
  @@index([societyId])
}

model MoveRequest {
  id                 String            @id @default(uuid())
  societyId          String
  society            Society           @relation(fields: [societyId], references: [id])
  unitId             String
  unit               Unit              @relation(fields: [unitId], references: [id])
  requestedById      String
  type               MoveRequestType
  status             MoveRequestStatus @default(pending)
  residentName       String
  residentPhone      String
  residentEmail      String?
  residentType       ResidentType      @default(tenant)
  rentalAgreementUrl String?
  idProofUrl         String?
  vehicleNumbers     Json?
  memberCount        Int?
  expectedDate       DateTime?
  pendingDues        Decimal?          @db.Decimal(10,2)
  nocIssuedAt        DateTime?
  nocIssuedById      String?
  approvedAt         DateTime?
  approvedById       String?
  rejectionReason    String?
  completedAt        DateTime?
  notes              String?
  createdAt          DateTime          @default(now())
  updatedAt          DateTime          @updatedAt
  @@index([societyId])
  @@index([status])
}

model Amenity {
  id              String        @id @default(uuid())
  societyId       String
  society         Society       @relation(fields: [societyId], references: [id])
  name            String
  description     String?
  capacity        Int?
  bookingDuration Int           @default(60)   // minutes per slot
  openTime        String        // "06:00"
  closeTime       String        // "22:00"
  bookingFee      Decimal       @default(0) @db.Decimal(10,2)
  maxAdvanceDays  Int           @default(7)
  photoUrl        String?
  status          AmenityStatus @default(active)
  closurePeriods  Json?         // [{from,to,reason}]
  rules           String?
  requireApproval Boolean       @default(false)
  createdAt       DateTime      @default(now())
  updatedAt       DateTime      @updatedAt
  bookings        AmenityBooking[]
  @@index([societyId])
}

model AmenityBooking {
  id              String        @id @default(uuid())
  amenityId       String
  amenity         Amenity       @relation(fields: [amenityId], references: [id])
  societyId       String
  society         Society       @relation(fields: [societyId], references: [id])
  unitId          String
  unit            Unit          @relation(fields: [unitId], references: [id])
  bookedById      String
  bookingDate     DateTime      @db.Date
  startTime       String
  endTime         String
  status          BookingStatus @default(pending)
  guestCount      Int?
  purpose         String?
  feeCharged      Decimal       @default(0) @db.Decimal(10,2)
  paymentStatus   String?
  razorpayOrderId String?
  approvedById    String?
  approvedAt      DateTime?
  cancelledAt     DateTime?
  cancelReason    String?
  createdAt       DateTime      @default(now())
  updatedAt       DateTime      @updatedAt
  @@unique([amenityId, bookingDate, startTime])
  @@index([societyId])
}

model GatePass {
  id              String         @id @default(uuid())
  societyId       String
  society         Society        @relation(fields: [societyId], references: [id])
  unitId          String
  unit            Unit           @relation(fields: [unitId], references: [id])
  createdById     String
  passCode        String         @unique  // 8-char readable alphanumeric
  itemDescription String
  reason          String?
  validFrom       DateTime
  validTo         DateTime
  status          GatePassStatus @default(active)
  scannedById     String?
  scannedAt       DateTime?
  notes           String?
  createdAt       DateTime       @default(now())
  @@index([societyId])
  @@index([passCode])
}
```

After writing schema:
```bash
npx prisma migrate dev --name init
npx prisma generate
node prisma/seed.js   # creates 3 plans + super_admin user
```

Seed creates:
- Plans: basic (₹999/mo, 50 units, 1 sec), standard (₹2499/mo, 200 units, 3 sec), premium (₹4999/mo, unlimited)
- Super admin: email=admin@societymanager.in, password=SuperAdmin@123 (bcrypt cost 12)

---

## PHASE 2: BACKEND INFRASTRUCTURE

### 2.1 Folder Structure
```
src/
  config/         database.js redis.js s3.js firebase.js twilio.js razorpay.js
  middleware/     auth.js rbac.js societyScope.js planLimit.js errorHandler.js asyncWrapper.js upload.js
  modules/
    auth/         routes controller service test
    superadmin/   routes controller service test
    units/        routes controller service test
    users/        routes controller service test
    bills/        routes controller service test
    expenses/     routes controller service test
    visitors/     routes controller service test
    notifications/ routes controller service
    notices/      routes controller service
    complaints/   routes controller service
    staff/        routes controller service
    payments/     routes controller service
    dashboard/    routes controller service
    domestic-help/ routes controller service test
    delivery/     routes controller service test
    vehicles/     routes controller service test
    parking/      routes controller service
    move-requests/ routes controller service test
    amenities/    routes controller service test
    gate-pass/    routes controller service test
  jobs/           billGeneration overdueDection lateFee qrCleanup renewalReminder fcmCleanup
  utils/          qrGenerator.js pdfReceipt.js whatsapp.js fcm.js s3Upload.js fullCodeGenerator.js jwtHelper.js passCodeGenerator.js entryCodeGenerator.js
  app.js          server.js
```

### 2.2 app.js Routes
Mount: auth, /admin (super_admin only), societies, units, users, bills, expenses,
visitors, notifications, notices, complaints, staff, payments, dashboard,
domestic-help, deliveries, vehicles, parking, move-requests, amenities, gate-passes.
Apply: helmet, cors(FRONTEND_URL), json, morgan, rate-limit(/auth/login: 5/15min/IP), errorHandler last.

### 2.3 Key Middleware

**auth.js** — verify RS256 JWT → set req.user = {id, role, societyId}. 401 if invalid.

**rbac.js** — `requireRole(...roles)` factory. 403 if role not in list.

**planLimit.js** — `checkPlanLimit(feature)` factory. Load society plan, check features JSONB. Return 403 with `{ upgrade: true }` if exceeded.

**societyScope.js** — every non-admin route: verify req.user.societyId matches resource. 403 if mismatch.

---

## PHASE 3: BACKEND MODULES

Build order: auth → superadmin → units → users → bills → expenses → visitors → cron → dashboard → notifications → notices → complaints → staff → payments → domestic-help → delivery → vehicles → parking → move-requests → amenities → gate-pass.

### Auth Module
Endpoints: login (phone/email + password, RS256 JWT 15min, refresh 30d httpOnly cookie), refresh (rotate token), logout, change-password, forgot-password (6-digit OTP via WhatsApp, Redis 10min), verify-otp.
Tests: valid login, wrong password, rate limit (6th req = 429), refresh rotation, revocation.

### Super Admin Module (`/api/v1/admin/*`, role=super_admin only)
```
GET  /dashboard          → MRR, ARR, societies by plan, revenue 12mo, renewals, recent
GET  /societies          → paginated, filter plan/status
POST /societies          → create society + pramukh login + WhatsApp welcome
GET  /societies/:id
PATCH /societies/:id
PATCH /societies/:id/suspend
PATCH /societies/:id/activate
DELETE /societies/:id    → soft delete
POST /societies/:id/pramukh → create/replace pramukh
GET  /societies/:id/stats
GET  /plans, POST /plans, PATCH /plans/:id
GET  /revenue            → CSV export available
GET  /subscriptions, POST /subscriptions → record payment
GET  /renewals?days=30
```

### Units Module
```
GET  /societies/:id/units  → paginated, filter wing/floor/status
POST /societies/:id/units  → check plan unit limit
PATCH /units/:id
DELETE /units/:id          → only if vacant
POST /units/:id/residents  → assign user
DELETE /units/:id/residents/:userId
POST /units/bulk-import    → CSV: wing,floor,unit_number,sub_unit,status,area_sqft
```

fullCodeGenerator logic:
```js
// wing+floor → "A-301A", wing only → "A-1", neither → "RH-1" (prefix from settings)
function generateFullCode(wing, floor, unitNumber, subUnit, prefix='RH') {
  if (wing && floor) return `${wing}-${floor}${unitNumber}${subUnit||''}`
  if (wing) return `${wing}-${unitNumber}${subUnit||''}`
  return `${prefix}-${unitNumber}${subUnit||''}`
}
```

### Users Module
```
GET  /users               → own society, filter role/unit/search
POST /users/secretary     → Pramukh only, check plan limit, WhatsApp welcome
POST /users/resident      → Secretary only, auto-password, WhatsApp welcome
POST /users/watchman      → Secretary only
PATCH /users/:id          → Pramukh/Secretary/Self
PATCH /users/:id/deactivate
GET  /users/me
```
WhatsApp welcome: `Welcome to Society Manager 🏠\nSociety: {name}\nPhone: {phone}\nPassword: {password}\nLogin: {url}\nChange password after first login.`

### Bills Module
```
GET  /bills               → Pramukh/Secretary, filter month/unit/status, paginated
GET  /bills/mine          → ANY role with unit assignment
GET  /bills/unit/:unitId
GET  /bills/defaulters
POST /bills/generate      → manual trigger for a month (idempotent)
PATCH /bills/:id/pay      → Resident=own unit only, Pramukh/Secretary=any unit
GET  /bills/:id/receipt   → generate PDF if not exists, return presigned URL
POST /bills/late-fee/apply
PATCH /maintenance/amount → per unit or category
```

Bill generation (ALWAYS idempotent):
```js
// for each occupied unit: findUnique({unitId, billingMonth}) → skip if exists, create if not
```

PDF receipt: pdfkit, include society name/logo, unit, resident, month, base+late fee+GST+total, payment method, receipt number. Upload S3 → presigned URL 7 days.

### Expenses Module
```
GET  /expenses            → all: approved feed
GET  /expenses/pending    → Pramukh: awaiting approval
POST /expenses            → Secretary
POST /expenses/:id/attachments/presign → S3 presigned PUT URL
POST /expenses/:id/attachments/confirm → save after upload
PATCH /expenses/:id/approve → Pramukh
PATCH /expenses/:id/reject  → Pramukh, requires rejectionReason
GET  /expenses/export     → CSV
```

### Visitors Module (WhatsApp QR)
```
POST /visitors/invite     → Resident: create, generate QR, upload S3, send WhatsApp
GET  /visitors/mine       → Resident
GET  /visitors            → Pramukh/Secretary
POST /visitors/validate   → Watchman: check Redis → one-time use → log → FCM push
GET  /visitors/log
GET  /visitors/log/today
```

Validate flow: Redis GET `visitor_qr:{token}` → if missing = expired/invalid → if found, check status != 'used' → DEL Redis + update DB to 'used' + create VisitorLog + FCM to resident.

### Cron Jobs (src/jobs/index.js)
```
0 0 1 * *   → bill generation all societies (idempotent)
0 9 * * *   → due-in-3-days reminder FCM + WhatsApp
0 10 * * *  → overdue detection → apply late fee if configured
0 2 * * *   → QR cleanup (sync DB status with Redis TTL)
0 8 * * *   → renewal reminder (7d, 3d, 0d before renewal date)
0 3 * * 0   → FCM token cleanup (90+ days inactive)
```

### Dashboard Module
```
GET /dashboard/admin    → MRR, ARR, by-plan, revenue trend, renewals
GET /dashboard/pramukh → totalUnits, occupancy, collection %, defaulters, expense summary
GET /dashboard/resident → myUnit, outstandingBalance, nextDue, recentPayments, notices
```
Use aggregation queries. Never N+1.

### Domestic Help Module
```
POST /domestic-help          → Resident/Secretary: register, auto-generate unique 6-digit code
GET  /domestic-help          → Secretary: all in society
GET  /domestic-help/unit/:id → Resident: own unit
PATCH /domestic-help/:id
PATCH /domestic-help/:id/suspend
PATCH /domestic-help/:id/remove
POST /domestic-help/log-entry → Watchman: code lookup + allowed day/hour check + FCM
POST /domestic-help/log-exit
GET  /domestic-help/:id/logs → monthly attendance
GET  /domestic-help/logs/today
```

Entry logic: check status=active, check allowedDays includes today's weekday, check allowedFrom <= now <= allowedTo → create log → FCM push `{name} has entered at {time}`.

### Delivery Module
```
POST /deliveries              → Watchman: create + FCM to all unit residents with action payload
GET  /deliveries/mine         → Resident: own
GET  /deliveries              → Secretary: all paginated
GET  /deliveries/today        → Watchman
PATCH /deliveries/:id/respond → Resident: allow|deny|leave_at_gate
PATCH /deliveries/:id/collect → Watchman: mark collected
```

### Vehicles Module
```
POST /vehicles            → Resident: own unit, Secretary: any unit
GET  /vehicles            → Secretary: all, Resident: own
GET  /vehicles/mine
PATCH /vehicles/:id
DELETE /vehicles/:id      → soft delete (isActive=false)
GET  /vehicles/lookup/:plate → Watchman: normalized plate search → unit + residents
GET  /parking/slots       → Secretary: all with assignment
POST /parking/slots
PATCH /parking/slots/:id/assign
PATCH /parking/slots/:id/unassign
```

### Move Requests Module
```
POST /move-requests/move-out → Resident/Secretary: check dues, create request, notify secretary + owner
POST /move-requests/move-in  → Secretary: new resident details, create user, send welcome
GET  /move-requests          → Secretary: all, Resident: own
PATCH /move-requests/:id/check-dues
PATCH /move-requests/:id/issue-noc  → only if pendingDues=0
PATCH /move-requests/:id/approve
PATCH /move-requests/:id/reject
PATCH /move-requests/:id/complete   → update unit status
POST /move-requests/:id/documents   → upload rental agreement / ID proof
```

### Amenities Module
```
GET  /amenities                    → all: list amenities
POST /amenities                    → Secretary: create
PATCH /amenities/:id
PATCH /amenities/:id/closure       → add/remove closure period
GET  /amenities/:id/slots?date=    → generate available slots, exclude booked
POST /amenities/:id/bookings       → Resident: book slot
GET  /amenities/:id/bookings       → Secretary: all bookings
GET  /amenities/bookings/mine      → Resident
PATCH /amenities/bookings/:id/approve
PATCH /amenities/bookings/:id/cancel
```

Slot generation: iterate openTime→closeTime by bookingDuration, exclude slots in existing confirmed/pending bookings, exclude closure periods.

### Gate Pass Module
```
POST /gate-passes            → Resident: generate with 8-char code
GET  /gate-passes/mine       → Resident
GET  /gate-passes            → Secretary
POST /gate-passes/verify     → Watchman: check code → one-time use → mark used
PATCH /gate-passes/:id/cancel
```

Pass code: chars=`ABCDEFGHJKMNPQRSTUVWXYZ23456789` (no O/0/I/l), 8 chars random. One-time use — mark used on first verify.

### Payments Module (Razorpay)
```
POST /payments/create-order → Razorpay createOrder → return orderId
POST /payments/verify       → verify HMAC signature → mark bill paid → generate receipt
```
Signature: `hmac('sha256', keySecret).update(orderId+'|'+paymentId).digest('hex')`

---

## PHASE 2.5: FLUTTER DESIGN SYSTEM

**Build ALL of this before writing any screen. Run `flutter analyze` after each file.**

### Colour System — `lib/core/theme/app_colors.dart`
```dart
class AppColors {
  static const primary        = Color(0xFF1B3A6B);
  static const primaryLight   = Color(0xFF2D5AA0);
  static const primarySurface = Color(0xFFEEF2FF);
  static const success        = Color(0xFF22C55E);
  static const successSurface = Color(0xFFF0FDF4);
  static const successText    = Color(0xFF166534);
  static const danger         = Color(0xFFEF4444);
  static const dangerSurface  = Color(0xFFFEF2F2);
  static const dangerText     = Color(0xFF991B1B);
  static const warning        = Color(0xFFF59E0B);
  static const warningSurface = Color(0xFFFFFBEB);
  static const warningText    = Color(0xFF92400E);
  static const info           = Color(0xFF3B82F6);
  static const infoSurface    = Color(0xFFEFF6FF);
  static const background     = Color(0xFFF5F7FA);
  static const surface        = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF8F9FF);
  static const border         = Color(0xFFE8EAF6);
  static const textPrimary    = Color(0xFF1A1A2E);
  static const textSecondary  = Color(0xFF4A4A6A);
  static const textMuted      = Color(0xFF8B8FA8);
  static const textOnPrimary  = Color(0xFFFFFFFF);
}
```

### Typography — `lib/core/theme/app_text_styles.dart`
Use `google_fonts` package. Two fonts only:
- **Plus Jakarta Sans** — displayLarge(28,w800), displayMedium(22,w800), h1(20,w700), h2(16,w700), unitCode(15,w700), amountLarge(24,w800)
- **Inter** — h3(14,w600), bodyLarge(14,w400), bodyMedium(13,w400), bodySmall(12,w400), labelLarge(12,w600), labelMedium(11,w600), labelSmall(10,w500), caption(10,w400), onPrimary(13,w600)

### Spacing — `lib/core/theme/app_dimensions.dart`
```dart
static const xs=4.0, sm=8.0, md=12.0, lg=16.0, xl=20.0, xxl=24.0, xxxl=32.0;
static const screenPadding=16.0;
static const radiusSm=6.0, radiusMd=10.0, radiusLg=14.0, radiusXl=20.0;
static const sidebarWidth=220.0;
```

### Theme — `lib/core/theme/app_theme.dart`
```dart
ThemeData with:
  scaffoldBackgroundColor: AppColors.background
  AppBarTheme: background=primary, elevation=0, titleStyle=PlusJakartaSans 16 w700 white
  CardTheme: color=surface, elevation=0, border=AppColors.border 1px, radius=radiusLg
  ElevatedButtonTheme: primary bg, white text, full width, height 48, radius radiusMd, Inter 14 w700
  InputDecorationTheme: filled surfaceVariant, border radius radiusMd, focus border primary 1.5px
  BottomNavTheme: surface bg, selected=primary, unselected=textMuted, elevation=0
  SnackBarTheme: floating, textPrimary bg, white text, radius radiusMd
```

### Shared Widgets — `lib/shared/widgets/`

Build each widget completely before moving to screens.

**responsive_builder.dart**
```dart
class ResponsiveBuilder extends StatelessWidget {
  final Widget webChild;
  final Widget mobileChild;
  static const double breakpoint = 768.0;
  Widget build(context) => LayoutBuilder(
    builder: (_, c) => c.maxWidth >= breakpoint ? webChild : mobileChild
  );
}
```

**app_status_chip.dart** — coloured pill for BillStatus, VisitorStatus, DeliveryStatus, BookingStatus, GatePassStatus, ComplaintStatus:
- paid/valid/approved/confirmed/active → successSurface + successText
- overdue/invalid/rejected/expired → dangerSurface + dangerText
- pending/partial → warningSurface + warningText
- Font: Inter 11 w600, padding 4×8, radius radiusSm

**app_card.dart** — white surface, 1px border, radiusLg, optional onTap InkWell, optional leftBorderColor (3px left border for bill cards, radius 0 on left side)

**app_kpi_card.dart** — label(labelSmall/muted) above, value(displayMedium) below, optional trend(caption/success). isAccent=true → primary bg+white text.

**app_bill_card.dart** — AppCard with leftBorderColor by status, unit code(unitCode style), resident name(bodyMedium), status chip, amount right-aligned in status colour. Optional action button.

**app_empty_state.dart** — centred column: 64px circle(primarySurface bg + emoji 28sp), h2 title, bodyMedium subtitle(textMuted), optional outlined action button.

**app_loading_shimmer.dart** — Shimmer.fromColors(base=Color(0xFFE8EAF6), highlight=Color(0xFFF5F7FA)). Shape matches actual content. 5 card placeholders for lists.

**app_list_view.dart** — ScrollController detecting 200px from bottom → call onLoadMore. CircularProgressIndicator(small, primary) at bottom while loading. AppEmptyState when count=0.

**app_data_table.dart** — web only. Header: surfaceVariant bg, labelSmall bold. Rows: alternating surface/surfaceVariant. Pagination: 'X-Y of Z' + Prev/Next + page size 10/25/50. Sortable columns. Bulk select checkboxes.

**app_text_field.dart** — wraps TextFormField. Always AppTheme inputDecoration. Required: label, controller. Optional: hint, keyboardType, validator, suffix icon.

**app_bottom_sheet.dart** — white, radiusXl top corners, drag handle, scrollable content, sticky footer button. Use showModalBottomSheet.

**app_side_nav.dart** (web) — 220px, surfaceVariant bg, right border. Active: primarySurface bg + primary left border 2px. Groups separated by Divider.

**app_nav_bar.dart** (mobile) — BottomNavigationBar. Secretary/Pramukh: Home|Units|Bills|Visitors|More. Resident: Home|Bills|Visitors|Notices|More. Watchman: Scan|DomHelp|Delivery|Log|More.

**app_scaffold.dart** — wraps every screen. Mobile: Scaffold(appBar, body, bottomNav, optional FAB). Web: Row(AppSideNav, Expanded(Column(WebTopBar, body))).

### Design Rules (Claude Code must follow all)
- AppBar: ALWAYS primary background, white text/icons. Never white AppBar.
- Dashboard header: primary background card showing pending amount (large) + collected (green right side)
- Bill cards: 3px left border (red=overdue, green=paid, amber=pending), background tint #FFF8F8 for overdue
- Scan result: full-screen green (success) or red (danger), white icon 80px, auto-pop 5 seconds
- Forms: white bg (not grey), section labels in labelMedium uppercase, submit pinned to bottom
- Loading: ALWAYS AppLoadingShimmer, NEVER full-screen CircularProgressIndicator
- Errors: AppCard with dangerSurface, retry button
- Animations: flutter_animate. fade+slideY for page load (300ms). Scale for scan result. Stagger KPI cards (80ms delay each). Nothing else.

### FORBIDDEN in Flutter code:
- `Colors.*` → use AppColors.*
- `TextStyle(` → use AppTextStyles.*
- `Color(0x...` raw hex → use AppColors.*
- Gradients on backgrounds
- Heavy BoxShadow
- Font size < 10
- Full-screen CircularProgressIndicator

Verification after every screen:
```bash
flutter analyze
grep -r "Colors\." lib/features/ --include="*.dart"    # must be empty
grep -r "TextStyle(" lib/features/ --include="*.dart"   # must be empty
```

---

## PHASE 4: FLUTTER SCREENS

Build in this order. Every screen: create dart file → connect to repository/provider → write widget test.

### Auth (all roles)
- **LoginScreen** — email(super_admin) or phone/email(others). Web: left decorative panel (primary bg, logo, tagline). Mobile: centred form. Validation on submit.
- **OtpScreen** — Pinput 6-digit, auto-advance, resend countdown 60s
- **ChangePasswordScreen** — current+new+confirm

### Super Admin (web only — show "Web only" on mobile)
- **AdminDashboardScreen** — 4 KPI cards (MRR, ARR, active societies, expiring), PieChart plan distribution, BarChart revenue 12mo, upcoming renewals table
- **SocietiesListScreen** — ResponsiveBuilder: web DataTable(plan chip, status chip, unit count, actions), mobile cards infinite scroll
- **CreateSocietyScreen** — name, address, city, logo upload, contact, plan dropdown, start date, pramukh details
- **SocietyDetailScreen** — stats, payment history, edit plan
- **PlansScreen** — edit pricing and features per plan

### Secretary / Pramukh
- **DashboardScreen** — AppScaffold. Header card (primary bg, society name, pending+collected). 4 KPI cards (web) / 2-col grid (mobile). Quick action chips. Defaulters list.
- **UnitsListScreen** — ResponsiveBuilder. Filter: wing/floor/status. FAB = Add Unit (mobile)
- **UnitDetailScreen** — residents, bills, quick pay. Web: side panel. Mobile: full push.
- **AddEditUnitScreen** — wing(optional), floor(optional), unitNumber, subUnit(optional), status, area. Row house if wing+floor empty.
- **BillsListScreen** — filter month/unit/status. Web: bulk select + CSV export. Mobile: overdue=red left border.
- **BillDetailScreen** — amounts breakdown, record payment form (cash/upi/bank/online), PDF receipt button
- **DefaultersScreen** — sorted by overdue amount. Remind All FAB.
- **ExpenseFeedScreen** — category left-colour stripe cards. Pramukh: Approve/Reject actions.
- **AddExpenseScreen** — category, amount, date, description. File picker (web: drag-drop zone, mobile: file_picker).
- **SecretaryManagementScreen** — Pramukh only. List + Create Secretary form.
- **ResidentListScreen** — search by name/phone. FAB = Add Resident.
- **NoticesScreen** — pinned at top (pin icon). FAB = Add Notice (Secretary/Pramukh only).
- **SendNotificationScreen** — title, body, recipient picker (All/ByRole/SelectUnits chip multi-select)
- **SettingsScreen** — late fee, due day, QR expiry, GST, unit prefix, WhatsApp config

### Resident
- **ResidentDashboardScreen** — balance card(primary bg, amount large, due date), notices strip, recent payments
- **MyBillsScreen** — ResponsiveBuilder: web DataTable, mobile monthly cards. Pay button on each unpaid.
- **BillPayScreen** — amounts breakdown, Razorpay Pay button, UPI/Card/NetBanking options, download receipt
- **InviteVisitorScreen** — name, WhatsApp number, expected arrival(optional), note for watchman(optional)
- **MyVisitorsScreen** — pending QRs show countdown timer. Expired greyed.
- **ExpenseFeedScreen** — read only
- **MyComplaintsScreen** — FAB = Raise Complaint. Status workflow visible.
- **AmenitiesListScreen** — grid cards with photo, name, hours, fee
- **AmenityDetailScreen** — calendar(table_calendar). Tap date → slot grid. Book button.
- **MyBookingsScreen** — upcoming + past. Cancel on upcoming.
- **GatePassListScreen** — status chips. FAB = Create Gate Pass.
- **CreateGatePassScreen** — item description, reason, validFrom, validTo. After create: show pass code large(44sp bold) + QR(qr_flutter) + Share/Copy buttons.
- **MoveOutRequestScreen** — expected date, resident type, notes. Show dues warning banner if any outstanding.
- **NotificationsScreen** — unread = primary left border.

### Watchman (mobile only — show "Use mobile app" message on web)
- **WatchmanHomeScreen** — full-width primary SCAN QR button(80px, camera icon, text+subtitle). 2×2 grid: DomesticHelp(primarySurface icon), Delivery(dangerSurface icon), VehicleLookup(successSurface icon), GatePass(warningSurface icon). Today's log below.
- **QrScannerScreen** — mobile_scanner full screen. Torch toggle floating bottom-left. Cancel floating bottom-right. White rounded rect scan guide centre.
- **ScanResultScreen** — full screen: VALID=success bg, INVALID=danger bg. White icon 80px. Visitor name displayLarge white. Unit/info h2 white. Auto-pop 5s with countdown. Reused for all scan types (QR, domestic help, gate pass).
- **DomesticHelpEntryScreen** — Pinput 6-digit numeric keypad. Submit → show ScanResultScreen (success/fail).
- **DeliveryLogScreen** — unit search(dropdown_search autocomplete), agent name, company dropdown(Amazon/Swiggy/Zomato/Blinkit/Other/custom). Submit → ScanResultScreen confirmation.
- **VehicleLookupScreen** — text field (auto-uppercase). Search → show unit code, residents, vehicle type in result card. "Not Registered" if not found.
- **GatePassVerifyScreen** — 8-char text field. Verify → ScanResultScreen (valid: item description shown, invalid: reason shown).
- **TodayLogScreen** — chronological cards. Timer.periodic 30s refresh.

### High Priority Feature Screens
- **DomesticHelpListScreen** — Resident: own. Secretary: all society. ResponsiveBuilder.
- **AddEditDomesticHelpScreen** — name, type dropdown, phone, photo, allowed days checkboxes, time range pickers.
- **DomesticHelpAttendanceScreen** — month selector, calendar showing E/X per day, summary: days in, days out.
- **DeliveriesListScreen** — Resident: pending deliveries at TOP with Allow/Deny/Leave at Gate buttons inline. Past below. ResponsiveBuilder.
- **VehiclesListScreen** — Resident: own. Secretary: all. FAB = Add Vehicle. ResponsiveBuilder.
- **AddVehicleScreen** — plate, type, brand, model, colour.
- **ParkingManagementScreen** — Secretary only. Grid of slots: assigned(primarySurface), vacant(successSurface), visitor(warningSurface). Tap = assign/unassign dialog.
- **MoveRequestsListScreen** — Secretary: all filter type/status. Resident: own. Timeline widget for status steps. ResponsiveBuilder.
- **MoveInRequestScreen** — Secretary. Resident details, type, documents upload.
- **MoveRequestDetailScreen** — workflow timeline(timeline_tile). Actions: Check Dues, Issue NOC, Approve, Reject.

---

## PHASE 5: TESTS

Run after each module. Fix all failures before next.

**Backend must-pass tests (write explicitly, don't skip):**
- Auth: valid login, wrong password, rate limit 429 on 6th attempt, refresh rotation, cross-society 403
- Bills: generation idempotency (run twice → 1 bill), pay own unit(resident OK), pay other unit(resident 403)
- Visitors: full flow invite→validate→validate again(fail), expired QR = INVALID
- Domestic help: valid code+correct day/time = success, suspended = fail, wrong time = fail
- Delivery: create+notify, resident respond, non-resident respond = 403
- Gate pass: verify once = valid, verify twice = used error
- Amenity: booked slot = 409, closure period = 0 slots
- Move out: pending dues blocks NOC, no dues = NOC issued

**Flutter must-pass widget tests:**
- ResponsiveBuilder: width 800 = DataTable, width 400 = ListView
- AppStatusChip: paid=green, overdue=red, pending=amber
- ScanResultScreen: valid=green fullscreen, invalid=red fullscreen, auto-pops in 5s
- BillCard: overdue has red left border, success has green
- AppLoadingShimmer renders shimmer not spinner
- AppEmptyState renders when list empty

---

## PHASE 6: SECURITY

Run before deployment. Fix every item:

```bash
npm audit --audit-level=high  # fix all high/critical
grep -r "password\|secret\|key" src/ --include="*.js" | grep -v ".env\|test\|bcrypt\|hash"
# Must return nothing
```

Verify manually:
- [ ] JWT is RS256 not HS256 — check jwtHelper.js
- [ ] Refresh token in httpOnly Secure SameSite=Strict cookie
- [ ] Refresh tokens in DB — revocable
- [ ] Rate limit working — test: 6 rapid login attempts → 6th is 429
- [ ] bcrypt cost = 12
- [ ] All routes have auth middleware — check app.js
- [ ] society_id in every query — grep services for `findMany` without where.societyId
- [ ] Zod on every POST/PATCH body
- [ ] File upload: MIME validation, 10MB limit in multer
- [ ] CORS restricted to FRONTEND_URL
- [ ] Helmet applied
- [ ] S3 block public access ON
- [ ] Flutter: flutter_secure_storage for tokens (not SharedPreferences)

---

## PHASE 7: DEPLOYMENT

### 7.1 Backend Dockerfile
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .
RUN npx prisma generate
EXPOSE 3000
CMD ["node", "src/server.js"]
```

### 7.2 docker-compose.yml
Services: postgres(15-alpine), redis(7-alpine), backend(built from Dockerfile), nginx(alpine).
Volumes for postgres and redis data. Backend depends_on postgres+redis. Nginx proxy to backend:3000, serves Flutter web build.

### 7.3 Nginx Config
```nginx
server {
  listen 443 ssl;
  server_name api.yourdomain.com;
  ssl_certificate /etc/ssl/certs/cert.pem;
  ssl_certificate_key /etc/ssl/private/key.pem;
  location / {
    proxy_pass http://backend:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    client_max_body_size 15M;
  }
}
server {
  listen 443 ssl;
  server_name app.yourdomain.com;
  root /var/www/flutter;
  index index.html;
  location / { try_files $uri $uri/ /index.html; }
}
server { listen 80; return 301 https://$server_name$request_uri; }
```

### 7.4 GitHub Actions — Backend (`.github/workflows/backend.yml`)
```yaml
on: push: branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npm run lint
      - run: npm test
        env: { DATABASE_URL: ${{secrets.TEST_DATABASE_URL}}, REDIS_URL: ${{secrets.TEST_REDIS_URL}}, JWT_PRIVATE_KEY: ${{secrets.JWT_PRIVATE_KEY}}, JWT_PUBLIC_KEY: ${{secrets.JWT_PUBLIC_KEY}} }
      - uses: appleboy/ssh-action@v1
        with:
          host: ${{secrets.EC2_HOST}}
          username: ubuntu
          key: ${{secrets.EC2_SSH_KEY}}
          script: cd ~/society-manager-backend && git pull && npm ci --production && npx prisma migrate deploy && pm2 restart backend
```

### 7.5 GitHub Actions — Flutter (`.github/workflows/flutter.yml`)
```yaml
on: push: branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.24.0' }
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - run: flutter build web --release --dart-define=API_URL=${{secrets.API_URL}}
      - uses: appleboy/scp-action@v0.1.7
        with:
          host: ${{secrets.EC2_HOST}}
          username: ubuntu
          key: ${{secrets.EC2_SSH_KEY}}
          source: build/web/*
          target: /var/www/flutter
          strip_components: 2
```

### 7.6 Environment Variables (.env.example)
```env
DATABASE_URL=postgresql://user:pass@host:5432/society_manager
REDIS_URL=redis://localhost:6379
JWT_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"
JWT_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----"
REFRESH_TOKEN_SECRET=min-32-chars-secret
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=ap-south-1
S3_BUCKET_NAME=society-manager-prod
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_WHATSAPP_NUMBER=whatsapp:+14155238886
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account",...}
RAZORPAY_KEY_ID=
RAZORPAY_KEY_SECRET=
PORT=3000
NODE_ENV=production
FRONTEND_URL=https://app.yourdomain.com
APP_URL=https://app.yourdomain.com
```

Generate RS256 keys:
```bash
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -pubout -out public.pem
```

---

## PHASE 8: PRODUCTION SMOKE TEST

Run after deployment. All must pass before calling it done.

```bash
BASE=https://api.yourdomain.com/api/v1

# 1. Health
curl $BASE/../health  # → { success: true }

# 2. Super Admin login
TOKEN=$(curl -s -X POST $BASE/auth/login -H "Content-Type:application/json" \
  -d '{"email":"admin@societymanager.in","password":"SuperAdmin@123"}' | jq -r '.accessToken')

# 3. Create plan
curl -X POST $BASE/admin/plans -H "Authorization:Bearer $TOKEN" \
  -d '{"name":"basic","displayName":"Basic","priceMonthly":999,"priceYearly":9990,"maxUnits":50,"maxSecretaries":1,"features":{"visitor_qr":true,"expense_approval":false,"attachments_count":0,"whatsapp":true,"pdf_receipts":true}}'

# 4. Create society + pramukh (copy planId from above response)
SOCIETY=$(curl -s -X POST $BASE/admin/societies -H "Authorization:Bearer $TOKEN" \
  -d '{"name":"Test Society","city":"Mumbai","planId":"<planId>","planStartDate":"2025-01-01","pramukh":{"name":"Test Pramukh","phone":"9999999999","email":"pramukh@test.com"}}')

# 5. Pramukh login → create secretary → secretary login → create resident → resident login
# 6. Secretary creates 5 units via CSV → generates bills → resident pays via Razorpay test mode
# 7. Resident invites visitor → watchman validates QR → VALID → same QR again → INVALID
# 8. Register domestic help → watchman enters code → FCM to resident
# 9. Log delivery → resident allows → watchman marks collected
# 10. Register vehicle → watchman looks up plate → finds unit
# 11. Create gate pass → watchman verifies → VALID → verify again → INVALID (used)
# 12. Book amenity slot → confirm → cancel → slot available again
# 13. Raise move-out → check dues → issue NOC → complete → unit = vacant
```

---

## WHAT TO DO WHEN STUCK

After 3 failed attempts on any item:
1. Write to ERRORS.md: file, line, error, what was tried
2. Add `// TODO: FAILED — see ERRORS.md` at the location
3. Continue to next item
4. Return to ERRORS.md items at the very end

---

## COMPLETION CHECKLIST

### Backend Core
- [ ] Prisma schema — all models, enums, indexes, migrations
- [ ] Seed — 3 plans + super admin
- [ ] Auth module + tests
- [ ] Super Admin module (16 endpoints) + tests
- [ ] Units + CSV import + tests
- [ ] Users + WhatsApp welcome + tests
- [ ] Bills + idempotent generation + receipt PDF + tests
- [ ] Expenses + S3 presigned upload + tests
- [ ] Visitors + WhatsApp QR + validate + tests
- [ ] All 6 cron jobs
- [ ] Dashboard — admin, pramukh, resident
- [ ] Notifications, Notices, Complaints, Staff, Payments modules

### Backend High Priority
- [ ] Domestic Help + code entry + FCM + tests
- [ ] Delivery + resident respond + tests
- [ ] Vehicles + plate lookup + Parking slots + tests
- [ ] Move Requests + NOC flow + owner notification + tests
- [ ] Amenities + slot generation + booking + Razorpay optional + tests
- [ ] Gate Pass + one-time verify + tests

### Flutter Design System
- [ ] AppColors, AppTextStyles, AppDimensions, AppTheme
- [ ] All shared widgets (AppCard, AppKpiCard, AppBillCard, AppStatusChip, AppEmptyState, AppLoadingShimmer, AppListView, AppDataTable, AppTextField, AppBottomSheet, AppNavBar, AppSideNav, AppScaffold, ResponsiveBuilder)
- [ ] `flutter analyze` clean on all shared widgets
- [ ] No `Colors.*` or `TextStyle(` in any widget

### Flutter Screens
- [ ] Auth: Login, OTP, ChangePassword
- [ ] Super Admin: Dashboard, Societies, CreateSociety, Plans
- [ ] Secretary/Pramukh: Dashboard, Units, UnitDetail, AddEditUnit, Bills, BillDetail, Defaulters, Expenses, AddExpense, SecretaryMgmt, Residents, Notices, SendNotification, Settings
- [ ] Resident: Dashboard, MyBills, BillPay, InviteVisitor, MyVisitors, ExpenseFeed, MyComplaints, Amenities, AmenityDetail, MyBookings, GatePass, CreateGatePass, MoveOutRequest, Notifications
- [ ] Watchman: Home, QrScanner, ScanResult, DomHelpEntry, DeliveryLog, VehicleLookup, GatePassVerify, TodayLog
- [ ] HP Screens: DomHelpList+AddEdit+Attendance, DeliveriesList, VehiclesList+Add+Parking, MoveRequests+Detail+MoveIn, AmenityList+Detail+Bookings+Manage, GatePassList
- [ ] All widget tests passing
- [ ] flutter build web succeeds
- [ ] flutter build apk succeeds

### Deployment
- [ ] GitHub Actions backend pipeline
- [ ] GitHub Actions Flutter pipeline
- [ ] Nginx config with SSL
- [ ] All 13 smoke tests passing

---

## START

```bash
mkdir society-manager-backend && cd society-manager-backend
```

Phase 0 → Phase 1 → Phase 2 → Phase 2.5 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7 → Phase 8.

Do not skip phases. Do not ask questions. Build everything. Fix every error.
