import { LoginResponseDto } from '@app/domain';
import { AssetController } from '@app/immich';
import { INestApplication } from '@nestjs/common';
import { api } from '@test/api';
import * as fs from 'fs';

import { LibraryType } from '@app/infra/entities';
import {
  IMMICH_TEST_ASSET_PATH,
  IMMICH_TEST_ASSET_TEMP_PATH,
  createTestApp,
  db,
  itif,
  restoreTempFolder,
  runAllTests,
} from '@test/test-utils';
import { exiftool } from 'exiftool-vendored';
import request from 'supertest';

describe(`${AssetController.name} (e2e)`, () => {
  let app: INestApplication;
  let server: any;
  let admin: LoginResponseDto;

  beforeAll(async () => {
    app = await createTestApp(true);
    server = app.getHttpServer();
  });

  beforeEach(async () => {
    await db.reset();
    await restoreTempFolder();
    await api.authApi.adminSignUp(server);
    admin = await api.authApi.adminLogin(server);
  });

  afterAll(async () => {
    await db.disconnect();
    await app.close();
    await restoreTempFolder();
  });

  describe.only('Thumbnail metadata', () => {
    itif(runAllTests)('should strip metadata of thumbnails', async () => {
      await fs.promises.cp(
        `${IMMICH_TEST_ASSET_PATH}/metadata/gps-position/thompson-springs.jpg`,
        `${IMMICH_TEST_ASSET_TEMP_PATH}/thompson-springs.jpg`,
      );

      const library = await api.libraryApi.create(server, admin.accessToken, {
        type: LibraryType.EXTERNAL,
        importPaths: [`${IMMICH_TEST_ASSET_TEMP_PATH}`],
      });

      await api.userApi.setExternalPath(server, admin.accessToken, admin.userId, '/');

      await api.libraryApi.scanLibrary(server, admin.accessToken, library.id);

      const assets = await api.assetApi.getAllAssets(server, admin.accessToken);

      expect(assets).toHaveLength(1);
      const assetWithLocation = assets[0];

      expect(assetWithLocation).toEqual(
        expect.objectContaining({ exifInfo: expect.objectContaining({ latitude: 1, longitude: 1 }) }),
      );

      const assetId = assetWithLocation.id;

      const { status, body } = await request(server)
        .get(`/asset/thumbnail/${assetId}`)
        .set('Authorization', `Bearer ${admin.accessToken}`);

      expect(status).toBe(200);

      await fs.promises.writeFile(`${IMMICH_TEST_ASSET_TEMP_PATH}/thumbnail.jpg`, body);

      const strippedAsset = await exiftool.read(`${IMMICH_TEST_ASSET_TEMP_PATH}/thumbnail.jpg`);

      expect(strippedAsset).not.toHaveProperty('GPSLongitude');
      expect(strippedAsset).not.toHaveProperty('GPSLatitude');
    });
  });
});
