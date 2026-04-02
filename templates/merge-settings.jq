# AXEL Settings Merge Filter
# Input: .[0] = existing settings, .[1] = AXEL template
# Strategy: existing always wins for scalars; arrays/objects get unioned

(.[0].env // {}) as $existing_env |
(.[1].env // {}) as $axel_env |
($axel_env + $existing_env) as $merged_env |

(.[0].permissions.allow // []) as $existing_allow |
(.[1].permissions.allow // []) as $axel_allow |
($existing_allow + ($axel_allow | map(select(. as $a | $existing_allow | map(. == $a) | any | not)))) as $merged_allow |

(.[0].permissions.deny // []) as $existing_deny |
(.[1].permissions.deny // []) as $axel_deny |
($existing_deny + ($axel_deny | map(select(. as $a | $existing_deny | map(. == $a) | any | not)))) as $merged_deny |

(.[0].hooks // {}) as $existing_hooks |
(.[1].hooks // {}) as $axel_hooks |
(($axel_hooks | keys) + ($existing_hooks | keys) | unique) as $all_events |
(reduce ($all_events[]) as $event (
  {};
  . + {
    ($event): (
      ($existing_hooks[$event] // []) as $existing_entries |
      ($axel_hooks[$event] // []) as $axel_entries |
      ($existing_entries | map(.hooks[0].command // "") | map(select(. != ""))) as $existing_cmds |
      ($axel_entries | map(
        select(
          (.hooks[0].command // "") as $cmd |
          ($existing_cmds | map(. == $cmd) | any | not)
        )
      )) as $new_entries |
      $existing_entries + $new_entries
    )
  }
)) as $merged_hooks |

(.[0].enabledPlugins // {}) as $existing_plugins |
(.[1].enabledPlugins // {}) as $axel_plugins |
($axel_plugins + $existing_plugins) as $merged_plugins |

(.[0].statusLine // .[1].statusLine) as $merged_statusline |

.[1] + .[0] +
{
  env: $merged_env,
  permissions: (.[0].permissions // {}) + {
    allow: $merged_allow,
    deny: $merged_deny
  },
  hooks: $merged_hooks,
  enabledPlugins: $merged_plugins,
  statusLine: $merged_statusline
}
