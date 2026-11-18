import 'package:floor/floor.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

/// PQRS migration numbers. They live here, in one place, because the number
/// may need renumbering when the PR is opened (another branch may take 23
/// first). If it changes, also update `@Database(version)` and the migration
/// list in `app_database.dart`.
const pqrsMigrationFromVersion = 22;
const pqrsMigrationToVersion = 23;

/// Adds the PQRS cache, the outbox and the cache of the two Supabase masters.
/// Only `CREATE ... IF NOT EXISTS`: it never touches existing tables. The DDL
/// must match what Floor generates for the entities in `database/model/pqrs`,
/// `image_format` and `pqrs_type`.
Future<void> createPqrsSchema(sqflite.DatabaseExecutor database) async {
  await database.execute(
    'CREATE TABLE IF NOT EXISTS `pqrs_cache` (`id` TEXT NOT NULL, '
    '`clientId` TEXT NOT NULL, `ownerId` TEXT NOT NULL, '
    '`motelId` TEXT NOT NULL, `motelName` TEXT NOT NULL, '
    '`clientName` TEXT NOT NULL, `type` TEXT NOT NULL, '
    '`subject` TEXT NOT NULL, `description` TEXT NOT NULL, '
    '`status` TEXT NOT NULL, `resolvedAt` INTEGER, `closedBy` TEXT, '
    '`photoCount` INTEGER NOT NULL, `createdAt` INTEGER NOT NULL, '
    '`updatedAt` INTEGER NOT NULL, PRIMARY KEY (`id`))',
  );
  await database.execute(
    'CREATE INDEX IF NOT EXISTS `index_pqrs_cache_clientId` '
    'ON `pqrs_cache` (`clientId`)',
  );
  await database.execute(
    'CREATE INDEX IF NOT EXISTS `index_pqrs_cache_ownerId` '
    'ON `pqrs_cache` (`ownerId`)',
  );
  await database.execute(
    'CREATE TABLE IF NOT EXISTS `pqrs_trace_cache` (`id` TEXT NOT NULL, '
    '`pqrsId` TEXT NOT NULL, `authorId` TEXT NOT NULL, '
    '`authorRole` TEXT NOT NULL, `authorName` TEXT, '
    '`message` TEXT NOT NULL, `statusChange` TEXT, '
    '`photoCount` INTEGER NOT NULL, `createdAt` INTEGER NOT NULL, '
    'PRIMARY KEY (`id`))',
  );
  await database.execute(
    'CREATE INDEX IF NOT EXISTS `index_pqrs_trace_cache_pqrsId` '
    'ON `pqrs_trace_cache` (`pqrsId`)',
  );
  await database.execute(
    'CREATE TABLE IF NOT EXISTS `pqrs_outbox` (`id` TEXT NOT NULL, '
    '`pqrsId` TEXT NOT NULL, `action` TEXT NOT NULL, '
    '`payload` TEXT NOT NULL, `syncStatus` TEXT NOT NULL, '
    '`errorMessage` TEXT, `createdAt` INTEGER NOT NULL, '
    '`attempts` INTEGER NOT NULL, PRIMARY KEY (`id`))',
  );
  await database.execute(
    'CREATE INDEX IF NOT EXISTS `index_pqrs_outbox_pqrsId` '
    'ON `pqrs_outbox` (`pqrsId`)',
  );
  await database.execute(
    'CREATE INDEX IF NOT EXISTS `index_pqrs_outbox_syncStatus` '
    'ON `pqrs_outbox` (`syncStatus`)',
  );
  await database.execute(
    'CREATE TABLE IF NOT EXISTS `pqrs_outbox_photo` (`id` TEXT NOT NULL, '
    '`outboxId` TEXT NOT NULL, `mimeType` TEXT NOT NULL, '
    '`bytes` BLOB NOT NULL, '
    'FOREIGN KEY (`outboxId`) REFERENCES `pqrs_outbox` (`id`) '
    'ON UPDATE NO ACTION ON DELETE CASCADE, PRIMARY KEY (`id`))',
  );
  await database.execute(
    'CREATE INDEX IF NOT EXISTS `index_pqrs_outbox_photo_outboxId` '
    'ON `pqrs_outbox_photo` (`outboxId`)',
  );
  await database.execute(
    'CREATE TABLE IF NOT EXISTS `allowed_image_formats` (`id` INTEGER NOT NULL, '
    '`mimeType` TEXT NOT NULL, `extensions` TEXT NOT NULL, '
    '`signatures` TEXT NOT NULL, `maxSizeBytes` INTEGER NOT NULL, '
    '`isActive` INTEGER NOT NULL, PRIMARY KEY (`id`))',
  );
  await database.execute(
    'CREATE TABLE IF NOT EXISTS `pqrs_types` (`id` INTEGER NOT NULL, '
    '`code` TEXT NOT NULL, `name` TEXT NOT NULL, '
    '`description` TEXT NOT NULL, `responseDays` INTEGER NOT NULL, '
    '`allowsPhotos` INTEGER NOT NULL, `sortOrder` INTEGER NOT NULL, '
    '`isActive` INTEGER NOT NULL, PRIMARY KEY (`id`))',
  );
}

final migration22To23 = Migration(
  pqrsMigrationFromVersion,
  pqrsMigrationToVersion,
  createPqrsSchema,
);
