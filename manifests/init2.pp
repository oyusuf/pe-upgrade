class pe-upgrade::init2 {
  class { "pe-upgrade":
   pe_version => hiera ("pe-upgrade::pe_version"),
  }
}
