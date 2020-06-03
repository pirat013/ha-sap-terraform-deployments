module "local_execution" {
  source  = "../generic_modules/local_exec"
  enabled = var.pre_deployment
}

# This locals entry is used to store the IP addresses of all the machines.
# Autogenerated addresses example based in 10.0.0.0/24
# Iscsi server: 10.0.0.4
# Monitoring: 10.0.0.5
# Hana ips: 10.0.0.10, 10.0.0.11
# Hana cluster vip: 10.0.1.12
# DRBD ips: 10.0.0.20, 10.0.0.21
# DRBD cluster vip: 10.0.1.22
# Netweaver ips: 10.0.0.30, 10.0.0.31, 10.0.0.32, 10.0.0.33
# Netweaver virtual ips: 10.0.1.34, 10.0.1.35, 10.0.1.36, 10.0.1.37
# If the addresses are provided by the user they will always have preference
locals {
  iscsi_srv_ip      = var.iscsi_srv_ip != "" ? var.iscsi_srv_ip : cidrhost(local.subnet_address_range, 4)
  monitoring_srv_ip = var.monitoring_srv_ip != "" ? var.monitoring_srv_ip : cidrhost(local.subnet_address_range, 5)

  hana_ip_start    = 10
  hana_ips         = length(var.hana_ips) != 0 ? var.hana_ips : [for ip_index in range(local.hana_ip_start, local.hana_ip_start + var.hana_count) : cidrhost(local.subnet_address_range, ip_index)]
  hana_cluster_vip = var.hana_cluster_vip != "" ? var.hana_cluster_vip : cidrhost(cidrsubnet(local.subnet_address_range, -8, 0), 256 + local.hana_ip_start + var.hana_count)

  # 2 is hardcoded for drbd because we always deploy 4 machines
  drbd_ip_start    = 20
  drbd_ips         = length(var.drbd_ips) != 0 ? var.drbd_ips : [for ip_index in range(local.drbd_ip_start, local.drbd_ip_start + 2) : cidrhost(local.subnet_address_range, ip_index)]
  drbd_cluster_vip = var.drbd_cluster_vip != "" ? var.drbd_cluster_vip : cidrhost(cidrsubnet(local.subnet_address_range, -8, 0), 256 + local.drbd_ip_start + 2)

  netweaver_ip_start    = 30
  netweaver_count       = var.netweaver_enabled ? (var.netweaver_ha_enabled ? 4 : 2) : 0
  netweaver_ips         = length(var.netweaver_ips) != 0 ? var.netweaver_ips : [for ip_index in range(local.netweaver_ip_start, local.netweaver_ip_start + local.netweaver_count) : cidrhost(local.subnet_address_range, ip_index)]
  netweaver_virtual_ips = length(var.netweaver_virtual_ips) != 0 ? var.netweaver_virtual_ips : [for ip_index in range(local.netweaver_ip_start, local.netweaver_ip_start + local.netweaver_count) : cidrhost(cidrsubnet(local.subnet_address_range, -8, 0), 256 + ip_index + 4)]

  # Check if iscsi server has to be created
  iscsi_enabled = var.sbd_storage_type == "iscsi" && ((var.hana_count > 1 && var.hana_cluster_sbd_enabled == true) || (var.drbd_enabled && var.drbd_cluster_sbd_enabled == true) || (var.netweaver_enabled && var.netweaver_cluster_sbd_enabled == true)) ? true : false
}

module "drbd_node" {
  source                 = "./modules/drbd_node"
  drbd_count             = var.drbd_enabled == true ? 2 : 0
  machine_type           = var.drbd_machine_type
  compute_zones          = data.google_compute_zones.available.names
  network_name           = local.vpc_name
  network_subnet_name    = local.subnet_name
  drbd_image             = var.drbd_image
  drbd_data_disk_size    = var.drbd_data_disk_size
  drbd_data_disk_type    = var.drbd_data_disk_type
  drbd_cluster_vip       = local.drbd_cluster_vip
  gcp_credentials_file   = var.gcp_credentials_file
  network_domain         = "tf.local"
  host_ips               = local.drbd_ips
  sbd_enabled            = var.drbd_cluster_sbd_enabled
  sbd_storage_type       = var.sbd_storage_type
  iscsi_srv_ip           = module.iscsi_server.iscsisrv_ip
  public_key_location    = var.public_key_location
  private_key_location   = var.private_key_location
  cluster_ssh_pub        = var.cluster_ssh_pub
  cluster_ssh_key        = var.cluster_ssh_key
  reg_code               = var.reg_code
  reg_email              = var.reg_email
  reg_additional_modules = var.reg_additional_modules
  ha_sap_deployment_repo = var.ha_sap_deployment_repo
  monitoring_enabled     = var.monitoring_enabled
  devel_mode             = var.devel_mode
  provisioner            = var.provisioner
  background             = var.background
  on_destroy_dependencies = [
    google_compute_firewall.ha_firewall_allow_tcp
  ]
}

module "netweaver_node" {
  source                     = "./modules/netweaver_node"
  netweaver_count            = local.netweaver_count
  machine_type               = var.netweaver_machine_type
  compute_zones              = data.google_compute_zones.available.names
  network_name               = local.vpc_name
  network_subnet_name        = local.subnet_name
  netweaver_image            = var.netweaver_image
  gcp_credentials_file       = var.gcp_credentials_file
  network_domain             = "tf.local"
  host_ips                   = local.netweaver_ips
  sbd_enabled                = var.netweaver_cluster_sbd_enabled
  sbd_storage_type           = var.sbd_storage_type
  iscsi_srv_ip               = module.iscsi_server.iscsisrv_ip
  public_key_location        = var.public_key_location
  private_key_location       = var.private_key_location
  cluster_ssh_pub            = var.cluster_ssh_pub
  cluster_ssh_key            = var.cluster_ssh_key
  netweaver_product_id       = var.netweaver_product_id
  netweaver_software_bucket  = var.netweaver_software_bucket
  netweaver_inst_folder      = var.netweaver_inst_folder
  netweaver_extract_dir      = var.netweaver_extract_dir
  netweaver_swpm_folder      = var.netweaver_swpm_folder
  netweaver_sapcar_exe       = var.netweaver_sapcar_exe
  netweaver_swpm_sar         = var.netweaver_swpm_sar
  netweaver_sapexe_folder    = var.netweaver_sapexe_folder
  netweaver_additional_dvds  = var.netweaver_additional_dvds
  netweaver_nfs_share        = "${local.drbd_cluster_vip}:/HA1"
  ha_enabled                 = var.netweaver_ha_enabled
  hana_ip                    = var.hana_ha_enabled ? local.hana_cluster_vip : element(local.hana_ips, 0)
  virtual_host_ips           = local.netweaver_virtual_ips
  reg_code                   = var.reg_code
  reg_email                  = var.reg_email
  reg_additional_modules     = var.reg_additional_modules
  ha_sap_deployment_repo     = var.ha_sap_deployment_repo
  devel_mode                 = var.devel_mode
  provisioner                = var.provisioner
  background                 = var.background
  monitoring_enabled         = var.monitoring_enabled
  on_destroy_dependencies = [
    google_compute_firewall.ha_firewall_allow_tcp
  ]
}

module "hana_node" {
  source                     = "./modules/hana_node"
  hana_count                 = var.hana_count
  machine_type               = var.machine_type
  compute_zones              = data.google_compute_zones.available.names
  network_name               = local.vpc_name
  network_subnet_name        = local.subnet_name
  sles4sap_boot_image        = var.sles4sap_boot_image
  gcp_credentials_file       = var.gcp_credentials_file
  host_ips                   = local.hana_ips
  sbd_enabled                = var.hana_cluster_sbd_enabled
  sbd_storage_type           = var.sbd_storage_type
  iscsi_srv_ip               = module.iscsi_server.iscsisrv_ip
  sap_hana_deployment_bucket = var.sap_hana_deployment_bucket
  hana_inst_folder           = var.hana_inst_folder
  hana_platform_folder       = var.hana_platform_folder
  hana_sapcar_exe            = var.hana_sapcar_exe
  hdbserver_sar              = var.hdbserver_sar
  hana_extract_dir           = var.hana_extract_dir
  hana_data_disk_type        = var.hana_data_disk_type
  hana_data_disk_size        = var.hana_data_disk_size
  hana_backup_disk_type      = var.hana_backup_disk_type
  hana_backup_disk_size      = var.hana_backup_disk_size
  hana_fstype                = var.hana_fstype
  hana_cluster_vip           = local.hana_cluster_vip
  ha_enabled                 = var.hana_ha_enabled
  scenario_type              = var.scenario_type
  public_key_location        = var.public_key_location
  private_key_location       = var.private_key_location
  cluster_ssh_pub            = var.cluster_ssh_pub
  cluster_ssh_key            = var.cluster_ssh_key
  reg_code                   = var.reg_code
  reg_email                  = var.reg_email
  reg_additional_modules     = var.reg_additional_modules
  ha_sap_deployment_repo     = var.ha_sap_deployment_repo
  additional_packages        = var.additional_packages
  devel_mode                 = var.devel_mode
  hwcct                      = var.hwcct
  qa_mode                    = var.qa_mode
  provisioner                = var.provisioner
  background                 = var.background
  monitoring_enabled         = var.monitoring_enabled
  on_destroy_dependencies = [
    google_compute_firewall.ha_firewall_allow_tcp
  ]
}

module "monitoring" {
  source                 = "./modules/monitoring"
  compute_zones          = data.google_compute_zones.available.names
  network_subnet_name    = local.subnet_name
  sles4sap_boot_image    = var.sles4sap_boot_image
  public_key_location    = var.public_key_location
  private_key_location   = var.private_key_location
  reg_code               = var.reg_code
  reg_email              = var.reg_email
  reg_additional_modules = var.reg_additional_modules
  ha_sap_deployment_repo = var.ha_sap_deployment_repo
  additional_packages    = var.additional_packages
  monitoring_srv_ip      = local.monitoring_srv_ip
  monitoring_enabled     = var.monitoring_enabled
  hana_targets           = concat(local.hana_ips, var.hana_ha_enabled ? [local.hana_cluster_vip] : []) # we use the vip to target the active hana instance
  drbd_targets           = var.drbd_enabled ? local.drbd_ips : []
  netweaver_targets      = var.netweaver_enabled ? local.netweaver_virtual_ips : []
  provisioner            = var.provisioner
  background             = var.background
  on_destroy_dependencies = [
    google_compute_firewall.ha_firewall_allow_tcp
  ]
}

module "iscsi_server" {
  iscsi_count             = local.iscsi_enabled == true ? 1 : 0
  source                  = "./modules/iscsi_server"
  machine_type            = var.machine_type_iscsi_server
  compute_zones           = data.google_compute_zones.available.names
  network_subnet_name     = local.subnet_name
  iscsi_server_boot_image = var.iscsi_server_boot_image
  host_ips                = [local.iscsi_srv_ip]
  lun_count               = var.iscsi_lun_count
  iscsi_disk_size         = var.iscsi_disk_size
  public_key_location     = var.public_key_location
  private_key_location    = var.private_key_location
  reg_code                = var.reg_code
  reg_email               = var.reg_email
  reg_additional_modules  = var.reg_additional_modules
  ha_sap_deployment_repo  = var.ha_sap_deployment_repo
  additional_packages     = var.additional_packages
  qa_mode                 = var.qa_mode
  provisioner             = var.provisioner
  background              = var.background
  on_destroy_dependencies = [
    google_compute_firewall.ha_firewall_allow_tcp
  ]
}
