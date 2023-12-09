import { Column, Entity, Index, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { AssetEntity } from './asset.entity';

@Entity('asset_keyframes')
@Index(['timestamp', 'assetId'])
export class AssetKeyframeEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  assetId!: string;

  @Column()
  timestamp!: string;

  @ManyToOne(() => AssetEntity, (asset) => asset.keyframes, { onDelete: 'CASCADE', onUpdate: 'CASCADE' })
  asset!: AssetEntity;

}
