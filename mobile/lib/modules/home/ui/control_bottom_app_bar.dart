import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/modules/album/ui/add_to_album_sliverlist.dart';
import 'package:immich_mobile/modules/home/models/selection_state.dart';
import 'package:immich_mobile/modules/home/ui/delete_dialog.dart';
import 'package:immich_mobile/modules/home/ui/upload_dialog.dart';
import 'package:immich_mobile/shared/providers/server_info.provider.dart';
import 'package:immich_mobile/shared/ui/drag_sheet.dart';
import 'package:immich_mobile/shared/models/album.dart';

class ControlBottomAppBar extends ConsumerWidget {
  final void Function(bool shareLocal) onShare;
  final void Function() onFavorite;
  final void Function() onArchive;
  final void Function() onDelete;
  final void Function(bool onlyMerged) onDeleteLocal;
  final Function(Album album) onAddToAlbum;
  final void Function() onCreateNewAlbum;
  final void Function() onUpload;
  final void Function() onStack;

  final List<Album> albums;
  final List<Album> sharedAlbums;
  final bool enabled;
  final SelectionAssetState selectionAssetState;

  const ControlBottomAppBar({
    Key? key,
    required this.onShare,
    required this.onFavorite,
    required this.onArchive,
    required this.onDelete,
    required this.onDeleteLocal,
    required this.sharedAlbums,
    required this.albums,
    required this.onAddToAlbum,
    required this.onCreateNewAlbum,
    required this.onUpload,
    required this.onStack,
    this.selectionAssetState = const SelectionAssetState(),
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var hasRemote =
        selectionAssetState.hasRemote || selectionAssetState.hasMerged;
    var hasLocal =
        selectionAssetState.hasLocal || selectionAssetState.hasMerged;
    final trashEnabled =
        ref.watch(serverInfoProvider.select((v) => v.serverFeatures.trash));

    List<Widget> renderActionButtons() {
      return [
        if (hasRemote)
          ControlBoxButton(
            iconData: Icons.share_rounded,
            label: "control_bottom_app_bar_share".tr(),
            onPressed: enabled ? () => onShare(false) : null,
          ),
        ControlBoxButton(
          iconData: Icons.ios_share_rounded,
          label: "control_bottom_app_bar_share_to".tr(),
          onPressed: enabled ? () => onShare(true) : null,
        ),
        if (hasRemote)
          ControlBoxButton(
            iconData: Icons.archive,
            label: "control_bottom_app_bar_archive".tr(),
            onPressed: enabled ? onArchive : null,
          ),
        if (hasRemote)
          ControlBoxButton(
            iconData: Icons.favorite_border_rounded,
            label: "control_bottom_app_bar_favorite".tr(),
            onPressed: enabled ? onFavorite : null,
          ),
        if (hasRemote)
          ControlBoxButton(
            iconData: Icons.delete_outline_rounded,
            label: "control_bottom_app_bar_delete".tr(),
            onPressed: enabled
                ? () {
                    if (!trashEnabled) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return DeleteDialog(
                            onDelete: onDelete,
                          );
                        },
                      );
                    } else {
                      onDelete();
                    }
                  }
                : null,
          ),
        if (hasLocal)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: ControlBoxButton(
              iconData: Icons.no_cell_rounded,
              label: "control_bottom_app_bar_delete_from_local".tr(),
              onPressed: enabled
                  ? () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return DeleteLocalOnlyDialog(
                            showWarning: selectionAssetState.hasLocal,
                            onDeleteLocal: onDeleteLocal,
                          );
                        },
                      );
                    }
                  : null,
            ),
          ),
        if (!hasLocal && selectionAssetState.selectedCount > 1)
          ControlBoxButton(
            iconData: Icons.filter_none_rounded,
            label: "control_bottom_app_bar_stack".tr(),
            onPressed: enabled ? onStack : null,
          ),
        if (hasLocal)
          ControlBoxButton(
            iconData: Icons.backup_outlined,
            label: "Upload",
            onPressed: enabled
                ? () => showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return UploadDialog(
                          onUpload: onUpload,
                        );
                      },
                    )
                : null,
          ),
      ];
    }

    return DraggableScrollableSheet(
      initialChildSize: hasRemote ? 0.30 : 0.18,
      minChildSize: 0.18,
      maxChildSize: hasRemote ? 0.60 : 0.18,
      snap: true,
      builder: (
        BuildContext context,
        ScrollController scrollController,
      ) {
        return Card(
          color: context.isDarkTheme ? Colors.grey[900] : Colors.grey[100],
          surfaceTintColor: Colors.transparent,
          elevation: 18.0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          margin: const EdgeInsets.all(0),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: 12),
                    const CustomDraggingHandle(),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: hasLocal ? 90 : 75,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: renderActionButtons(),
                      ),
                    ),
                    if (hasRemote)
                      const Divider(
                        indent: 16,
                        endIndent: 16,
                        thickness: 1,
                      ),
                    if (hasRemote)
                      AddToAlbumTitleRow(
                        onCreateNewAlbum: enabled ? onCreateNewAlbum : null,
                      ),
                  ],
                ),
              ),
              if (hasRemote)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: AddToAlbumSliverList(
                    albums: albums,
                    sharedAlbums: sharedAlbums,
                    onAddToAlbum: onAddToAlbum,
                    enabled: enabled,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class DeleteLocalOnlyDialog extends StatelessWidget {
  final bool showWarning;
  final void Function(bool onlyMerged) onDeleteLocal;

  const DeleteLocalOnlyDialog({
    super.key,
    this.showWarning = false,
    required this.onDeleteLocal,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: const Text("delete_dialog_title").tr(),
      content: Text(
        showWarning
            ? "delete_dialog_alert_local_non_backed_up"
            : "delete_dialog_alert_local",
      ).tr(),
      actions: [
        TextButton(
          onPressed: () => context.pop(false),
          child: Text(
            "delete_dialog_cancel",
            style: TextStyle(
              color: context.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ).tr(),
        ),
        if (showWarning)
          TextButton(
            onPressed: () {
              context.pop(true);
              onDeleteLocal(true);
            },
            child: Text(
              "delete_local_dialog_ok_backed_up_only",
              style: TextStyle(
                color: showWarning ? null : Colors.red[400],
                fontWeight: FontWeight.bold,
              ),
            ).tr(),
          ),
        TextButton(
          onPressed: () {
            context.pop(true);
            onDeleteLocal(false);
          },
          child: Text(
            showWarning ? "delete_local_dialog_ok_force" : "delete_dialog_ok",
            style: TextStyle(
              color: Colors.red[400],
              fontWeight: FontWeight.bold,
            ),
          ).tr(),
        ),
      ],
    );
  }
}

class AddToAlbumTitleRow extends StatelessWidget {
  const AddToAlbumTitleRow({
    super.key,
    required this.onCreateNewAlbum,
  });

  final VoidCallback? onCreateNewAlbum;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "common_add_to_album",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ).tr(),
          TextButton.icon(
            onPressed: onCreateNewAlbum,
            icon: Icon(
              Icons.add,
              color: context.primaryColor,
            ),
            label: Text(
              "common_create_new_album",
              style: TextStyle(
                color: context.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ).tr(),
          ),
        ],
      ),
    );
  }
}
