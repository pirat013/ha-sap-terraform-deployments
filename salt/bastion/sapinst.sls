xfsprogs:
  pkg.installed:
    - retry:
        attempts: 3
        interval: 15

nfs-kernel-server:
  pkg.installed:
    - retry:
        attempts: 3
        interval: 15

sapinst_fs:
  cmd.run:
    - name: |
        /sbin/mkfs -t xfs {{ grains['data_disk_device'] }}
    - require:
      - xfsprogs
    - unless:
      - xfs_info {{ grains['data_disk_device'] }}

sapinst_folder:
  file.directory:
   - name: /mnt_permanent/sapinst
   - user: root
   - mode: "0755"
   - makedirs: True
  mount.mounted:
    - name: /mnt_permanent/sapinst
    - device: {{ grains['data_disk_device'] }}
    - fstype: xfs
    - mkmnt: True
    - persist: True
    - opts:
      - defaults
    - only_if:
      - xfs_info {{ grains['data_disk_device'] }}

configure_nfs:
  nfs_export.present:
    - name: /mnt_permanent/sapinst
    - hosts: '*'
    - options:
      - rw
      - no_root_squash
      - fsid=0
      - no_subtree_check
    - require:
      - nfs-kernel-server
      - sapinst_folder

nfsserver:
  service:
    - running
    - enable: True
    - reload: True
    - watch:
      - configure_nfs
