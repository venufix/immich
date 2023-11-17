import { IJobRepository, JobItem, JobItemHandler, QueueName } from '@app/domain';
import { AppModule } from '@app/immich';
import { dataSource } from '@app/infra';
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import * as fs from 'fs';
import path from 'path';
import { Server } from 'tls';
import { EntityTarget, ObjectLiteral } from 'typeorm';
import { AppService } from '../src/microservices/app.service';

export const IMMICH_TEST_ASSET_PATH = process.env.IMMICH_TEST_ASSET_PATH;
export const IMMICH_TEST_ASSET_TEMP_PATH = path.normalize(`${IMMICH_TEST_ASSET_PATH}/temp/`);

export interface ResetOptions {
  entities?: EntityTarget<ObjectLiteral>[];
}
export const db = {
  reset: async (options?: ResetOptions) => {
    if (!dataSource.isInitialized) {
      await dataSource.initialize();
    }

    await dataSource.transaction(async (em) => {
      const entities = options?.entities || [];
      const tableNames =
        entities.length > 0
          ? entities.map((entity) => em.getRepository(entity).metadata.tableName)
          : dataSource.entityMetadatas.map((entity) => entity.tableName);

      let deleteUsers = false;
      for (const tableName of tableNames) {
        if (tableName === 'users') {
          deleteUsers = true;
          continue;
        }
        await em.query(`DELETE FROM ${tableName} CASCADE;`);
      }
      if (deleteUsers) {
        await em.query(`DELETE FROM "users" CASCADE;`);
      }
    });
  },
  disconnect: async () => {
    if (dataSource.isInitialized) {
      await dataSource.destroy();
    }
  },
};

let _handler: JobItemHandler = () => Promise.resolve();

interface TestAppOptions {
  jobs: boolean;
}

let app: INestApplication;

export const testApp = {
  create: async (options?: TestAppOptions): Promise<[any, INestApplication]> => {
    const { jobs } = options || { jobs: false };

    const moduleFixture = await Test.createTestingModule({ imports: [AppModule], providers: [AppService] })
      .overrideProvider(IJobRepository)
      .useValue({
        addHandler: (_queueName: QueueName, _concurrency: number, handler: JobItemHandler) => (_handler = handler),
        addCronJob: jest.fn(),
        updateCronJob: jest.fn(),
        deleteCronJob: jest.fn(),
        validateCronExpression: jest.fn(),
        queue: (item: JobItem) => jobs && _handler(item),
        resume: jest.fn(),
        empty: jest.fn(),
        setConcurrency: jest.fn(),
        getQueueStatus: jest.fn(),
        getJobCounts: jest.fn(),
        pause: jest.fn(),
      } as IJobRepository)
      .compile();

    app = await moduleFixture.createNestApplication().init();
    app.listen(0);

    if (jobs) {
      await app.get(AppService).init();
    }

    const httpServer = app.getHttpServer();
    const port = httpServer.address().port;
    const protocol = app instanceof Server ? 'https' : 'http';
    process.env.IMMICH_INSTANCE_URL = protocol + '://127.0.0.1:' + port;

    return [httpServer, app];
  },
  reset: async (options?: ResetOptions) => {
    await db.reset(options);
  },
  teardown: async () => {
    await app.get(AppService).teardown();
    await db.disconnect();
    await app.close();
  },
};

export const runAllTests: boolean = process.env.IMMICH_RUN_ALL_TESTS === 'true';

const directoryExists = async (dirPath: string) =>
  await fs.promises
    .access(dirPath)
    .then(() => true)
    .catch(() => false);

export async function restoreTempFolder(): Promise<void> {
  if (await directoryExists(`${IMMICH_TEST_ASSET_TEMP_PATH}`)) {
    // Temp directory exists, delete all files inside it
    await fs.promises.rm(IMMICH_TEST_ASSET_TEMP_PATH, { recursive: true });
  }
  // Create temp folder
  await fs.promises.mkdir(IMMICH_TEST_ASSET_TEMP_PATH);
}
