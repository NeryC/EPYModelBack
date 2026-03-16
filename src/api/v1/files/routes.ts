import { Router, Request, Response, NextFunction } from 'express';
import { getFileById, listFiles } from '../../../infrastructure/storage/file-repository.js';

const router = Router();

router.get('/files/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    if (!id) {
      return res.status(400).json({ error: 'File ID is required' });
    }
    const file = await getFileById(id);
    return res.download(file.path, file.name);
  } catch (err) {
    return next(err);
  }
});

// List files metadata
router.get('/files', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const items = await listFiles();
    return res.json({
      success: true,
      data: items.map(({ id, name, createdAt }) => ({ id, name, createdAt })),
    });
  } catch (err) {
    return next(err);
  }
});

export default router;
