class pe_agent_upgrade::init2 {
  class { "pe_agent_upgrade":
   pe_version => hiera ("pe_agent_upgrade::pe_version"),
  }
}
