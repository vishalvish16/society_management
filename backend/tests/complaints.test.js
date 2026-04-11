const request = require('supertest');
const app = require('../../app');
const { User, Complaint } = require('../../models');

describe('Complaint Endpoints', () => {
  beforeAll(async () => {
    await User.sync({ force: true });
    await Complaint.sync({ force: true });

    const testUser = await User.create({
      name: 'Test User',
      email: 'test@example.com',
      password: 'password123',
      phone: '9876543210',
      role: 'member',
      societyId: 1,
    });
    
    const testComplaint = await Complaint.create({
      userId: testUser.id,
      description: 'Test complaint',
      societyId: 1
    });

    app.use('/api/complaints', require('../complaints.routes'));
  });

  afterAll(async () => {
    await User.drop();
    await Complaint.drop();
  });

  it('should create a new complaint', async () => {
    const response = await request(app)
      .post('/api/complaints')
      .set('Authorization', 'Bearer jwt_token_here')
      .send({ description: "Test complaint" })
      .expect(201);

    expect(response.body.description).toBe("Test complaint");
  });

  it('should get all complaints', async () => {
    const response = await request(app)
      .get('/api/complaints')
      .set('Authorization', 'Bearer jwt_token_here')
      .expect(200);
    
    expect(Array.isArray(response.body)).toBe(true);
    expect(response.body.length).toBeGreaterThan(0);
  });

  it('should update a complaint', async () => {
    const testComplaint = await Complaint.findOne({ where: { description: "Test complaint" } });
    
    const response = await request(app)
      .put(`/api/complaints/${testComplaint.id}`)
      .set('Authorization', 'Bearer jwt_token_here')
      .send({ description: "Updated Test complaint" })
      .expect(200);

    expect(response.body.message).toBe("Complaint updated successfully");
  });

  it('should delete a complaint', async () => {
    const testComplaint = await Complaint.findOne({ where: { description: "Test complaint" } });
    
    const response = await request(app)
      .delete(`/api/complaints/${testComplaint.id}`)
      .set('Authorization', 'Bearer jwt_token_here')
      .expect(200);
    
    expect(response.body.message).toBe("Complaint deleted successfully");
  });

});

