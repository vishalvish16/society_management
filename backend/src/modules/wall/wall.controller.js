const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');
const notificationsService = require('../notifications/notifications.service');

function isAdmin(role) {
  const r = String(role || '').toUpperCase();
  return r === 'SUPER_ADMIN' || r === 'PRAMUKH' || r === 'CHAIRMAN' || r === 'SECRETARY';
}

function mediaTypeFromMime(mime) {
  return String(mime).startsWith('video/') ? 'VIDEO' : 'IMAGE';
}

// ── Create post ───────────────────────────────────────────────────────────────
async function createPost(req, res) {
  try {
    const { societyId, id: authorId } = req.user;
    const { body } = req.body || {};
    const files = req.files || [];

    if (!body && files.length === 0) {
      return sendError(res, 'Post must have text or at least one media file', 400);
    }
    if (files.length > 10) {
      return sendError(res, 'Maximum 10 media files per post', 400);
    }

    const post = await prisma.wallPost.create({
      data: {
        societyId,
        authorId,
        body: body ? String(body).trim() : null,
        media: {
          create: files.map((f, idx) => ({
            url: `/uploads/wall/${f.filename}`,
            mediaType: mediaTypeFromMime(f.mimetype),
            fileName: f.originalname,
            fileSize: f.size,
            sortOrder: idx,
          })),
        },
      },
      include: {
        author: { select: { id: true, name: true, profilePhotoUrl: true, role: true } },
        media: { orderBy: { sortOrder: 'asc' } },
        _count: { select: { comments: true, likes: true } },
      },
    });

    // Notify all society members asynchronously (best-effort)
    setImmediate(() => {
      const preview = (post.body || '').slice(0, 80) || 'Shared a photo/video';
      notificationsService
        .sendNotification(authorId, societyId, {
          targetType: 'all',
          title: `${post.author?.name || 'Someone'} posted on the Wall`,
          body: preview,
          type: 'MANUAL',
          route: '/wall',
        })
        .catch(() => {});
    });

    return sendSuccess(res, { ...post, likedByMe: false }, 'Post created', 201);
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// ── List posts (feed) — newest first, cursor-based pagination ─────────────────
async function listPosts(req, res) {
  try {
    const { societyId, id: userId, role } = req.user;
    const limit = Math.min(parseInt(req.query.limit) || 20, 50);
    const cursor = req.query.cursor || null; // createdAt ISO string for pagination

    const where = {
      societyId,
      deletedAt: null,
      isHidden: isAdmin(role) ? undefined : false, // admins see hidden posts
    };
    if (cursor) {
      where.createdAt = { lt: new Date(cursor) };
    }

    const posts = await prisma.wallPost.findMany({
      where,
      include: {
        author: { select: { id: true, name: true, profilePhotoUrl: true, role: true } },
        media: { orderBy: { sortOrder: 'asc' } },
        _count: { select: { comments: { where: { deletedAt: null, isHidden: false } }, likes: true } },
        likes: { where: { userId }, select: { id: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    const nextCursor = posts.length === limit ? posts[posts.length - 1].createdAt.toISOString() : null;
    const shaped = posts.map((p) => ({ ...p, likedByMe: p.likes.length > 0, likes: undefined }));

    return sendSuccess(res, { posts: shaped, nextCursor }, 'Wall feed retrieved');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// ── Get single post ───────────────────────────────────────────────────────────
async function getPost(req, res) {
  try {
    const { societyId, id: userId, role } = req.user;
    const { id } = req.params;

    const post = await prisma.wallPost.findUnique({
      where: { id },
      include: {
        author: { select: { id: true, name: true, profilePhotoUrl: true, role: true } },
        media: { orderBy: { sortOrder: 'asc' } },
        _count: { select: { comments: { where: { deletedAt: null, isHidden: false } }, likes: true } },
        likes: { where: { userId }, select: { id: true } },
      },
    });

    if (!post || post.societyId !== societyId || post.deletedAt) {
      return sendError(res, 'Post not found', 404);
    }
    if (post.isHidden && !isAdmin(role) && post.authorId !== userId) {
      return sendError(res, 'Post not found', 404);
    }

    return sendSuccess(res, { ...post, likedByMe: post.likes.length > 0, likes: undefined }, 'Post retrieved');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// ── Hide / unhide post ────────────────────────────────────────────────────────
async function toggleHidePost(req, res) {
  try {
    const { societyId, id: userId, role } = req.user;
    const { id } = req.params;

    const post = await prisma.wallPost.findUnique({ where: { id } });
    if (!post || post.societyId !== societyId || post.deletedAt) {
      return sendError(res, 'Post not found', 404);
    }

    const canAct = isAdmin(role) || post.authorId === userId;
    if (!canAct) return sendError(res, 'Forbidden', 403);

    const updated = await prisma.wallPost.update({
      where: { id },
      data: { isHidden: !post.isHidden },
    });

    return sendSuccess(res, updated, updated.isHidden ? 'Post hidden' : 'Post unhidden');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// ── Delete post ───────────────────────────────────────────────────────────────
async function deletePost(req, res) {
  try {
    const { societyId, id: userId, role } = req.user;
    const { id } = req.params;

    const post = await prisma.wallPost.findUnique({ where: { id } });
    if (!post || post.societyId !== societyId || post.deletedAt) {
      return sendError(res, 'Post not found', 404);
    }

    const canAct = isAdmin(role) || post.authorId === userId;
    if (!canAct) return sendError(res, 'Forbidden', 403);

    await prisma.wallPost.update({ where: { id }, data: { deletedAt: new Date() } });

    return sendSuccess(res, null, 'Post deleted');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// ── Add comment ───────────────────────────────────────────────────────────────
async function addComment(req, res) {
  try {
    const { societyId, id: authorId, role } = req.user;
    const { id: postId } = req.params;
    const { body } = req.body || {};

    if (!body || !String(body).trim()) return sendError(res, 'Comment body is required', 400);

    const post = await prisma.wallPost.findUnique({ where: { id: postId } });
    if (!post || post.societyId !== societyId || post.deletedAt) {
      return sendError(res, 'Post not found', 404);
    }
    if (post.isHidden && !isAdmin(role)) {
      return sendError(res, 'Post not found', 404);
    }

    const comment = await prisma.wallComment.create({
      data: { postId, authorId, body: String(body).trim() },
      include: { author: { select: { id: true, name: true, profilePhotoUrl: true, role: true } } },
    });

    return sendSuccess(res, comment, 'Comment added', 201);
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// ── List comments for a post ──────────────────────────────────────────────────
async function listComments(req, res) {
  try {
    const { societyId, id: userId, role } = req.user;
    const { id: postId } = req.params;
    const limit = Math.min(parseInt(req.query.limit) || 50, 100);
    const cursor = req.query.cursor || null;

    const post = await prisma.wallPost.findUnique({ where: { id: postId } });
    if (!post || post.societyId !== societyId || post.deletedAt) {
      return sendError(res, 'Post not found', 404);
    }
    if (post.isHidden && !isAdmin(role) && post.authorId !== userId) {
      return sendError(res, 'Post not found', 404);
    }

    const where = {
      postId,
      deletedAt: null,
      isHidden: isAdmin(role) ? undefined : false,
    };
    if (cursor) {
      where.createdAt = { gt: new Date(cursor) }; // older-first scroll
    }

    const comments = await prisma.wallComment.findMany({
      where,
      include: { author: { select: { id: true, name: true, profilePhotoUrl: true, role: true } } },
      orderBy: { createdAt: 'asc' },
      take: limit,
    });

    const nextCursor = comments.length === limit ? comments[comments.length - 1].createdAt.toISOString() : null;

    return sendSuccess(res, { comments, nextCursor }, 'Comments retrieved');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// ── Hide / unhide comment ─────────────────────────────────────────────────────
async function toggleHideComment(req, res) {
  try {
    const { societyId, id: userId, role } = req.user;
    const { id: postId, commentId } = req.params;

    const post = await prisma.wallPost.findUnique({ where: { id: postId } });
    if (!post || post.societyId !== societyId || post.deletedAt) {
      return sendError(res, 'Post not found', 404);
    }

    const comment = await prisma.wallComment.findUnique({ where: { id: commentId } });
    if (!comment || comment.postId !== postId || comment.deletedAt) {
      return sendError(res, 'Comment not found', 404);
    }

    // Admin can hide any comment; post author can hide comments on their post; comment author can hide own comment
    const canAct = isAdmin(role) || post.authorId === userId || comment.authorId === userId;
    if (!canAct) return sendError(res, 'Forbidden', 403);

    const updated = await prisma.wallComment.update({
      where: { id: commentId },
      data: { isHidden: !comment.isHidden },
    });

    return sendSuccess(res, updated, updated.isHidden ? 'Comment hidden' : 'Comment unhidden');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// ── Delete comment ────────────────────────────────────────────────────────────
async function deleteComment(req, res) {
  try {
    const { societyId, id: userId, role } = req.user;
    const { id: postId, commentId } = req.params;

    const post = await prisma.wallPost.findUnique({ where: { id: postId } });
    if (!post || post.societyId !== societyId || post.deletedAt) {
      return sendError(res, 'Post not found', 404);
    }

    const comment = await prisma.wallComment.findUnique({ where: { id: commentId } });
    if (!comment || comment.postId !== postId || comment.deletedAt) {
      return sendError(res, 'Comment not found', 404);
    }

    // Admin can delete any; post author can delete comments on their post; comment author can delete own
    const canAct = isAdmin(role) || post.authorId === userId || comment.authorId === userId;
    if (!canAct) return sendError(res, 'Forbidden', 403);

    await prisma.wallComment.update({ where: { id: commentId }, data: { deletedAt: new Date() } });

    return sendSuccess(res, null, 'Comment deleted');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// ── Who liked ────────────────────────────────────────────────────────────────
async function getLikes(req, res) {
  try {
    const { societyId, id: userId, role } = req.user;
    const { id: postId } = req.params;

    const post = await prisma.wallPost.findUnique({ where: { id: postId } });
    if (!post || post.societyId !== societyId || post.deletedAt) {
      return sendError(res, 'Post not found', 404);
    }
    if (post.isHidden && !isAdmin(role) && post.authorId !== userId) {
      return sendError(res, 'Post not found', 404);
    }

    const likes = await prisma.wallPostLike.findMany({
      where: { postId },
      include: { user: { select: { id: true, name: true, profilePhotoUrl: true, role: true } } },
      orderBy: { createdAt: 'desc' },
    });

    return sendSuccess(res, likes.map((l) => ({ ...l.user, likedAt: l.createdAt })), 'Likes retrieved');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// ── Toggle like ───────────────────────────────────────────────────────────────
async function toggleLike(req, res) {
  try {
    const { societyId, id: userId, role } = req.user;
    const { id: postId } = req.params;

    const post = await prisma.wallPost.findUnique({ where: { id: postId } });
    if (!post || post.societyId !== societyId || post.deletedAt) {
      return sendError(res, 'Post not found', 404);
    }
    if (post.isHidden && !isAdmin(role)) {
      return sendError(res, 'Post not found', 404);
    }

    const existing = await prisma.wallPostLike.findUnique({
      where: { postId_userId: { postId, userId } },
    });

    if (existing) {
      await prisma.wallPostLike.delete({ where: { id: existing.id } });
    } else {
      await prisma.wallPostLike.create({ data: { postId, userId } });
    }

    const likeCount = await prisma.wallPostLike.count({ where: { postId } });

    return sendSuccess(res, { likedByMe: !existing, likeCount }, existing ? 'Unliked' : 'Liked');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

module.exports = {
  createPost,
  listPosts,
  getPost,
  toggleHidePost,
  deletePost,
  getLikes,
  toggleLike,
  addComment,
  listComments,
  toggleHideComment,
  deleteComment,
};
