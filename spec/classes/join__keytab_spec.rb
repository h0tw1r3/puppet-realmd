require 'spec_helper'

describe 'realmd' do
  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) { os_facts }
        let(:params) do
          {
            krb_ticket_join: true,
            domain_join_user: 'user',
            krb_keytab: '/tmp/join.keytab',
            krb_config_file: '/etc/krb5.conf',
            domain: 'example.com',
            manage_krb_config: true,
          }
        end

        context 'realmd::join::keytab class with default krb_config' do
          it { is_expected.to contain_class('realmd::join::keytab') }

          it do
            is_expected.to contain_file('krb_keytab')
              .that_comes_before('Exec[run_kinit_with_keytab]')
              .with(
                path: '/tmp/join.keytab',
                owner: 'root',
                group: 'root',
                mode: '0400',
              )
          end

          it do
            is_expected.to contain_file('krb_configuration')
              .that_comes_before('Exec[run_kinit_with_keytab]')
              .with(
                path: '/etc/krb5.conf',
                owner: 'root',
                group: 'root',
                mode: '0644',
              )
          end

          it do
            is_expected.to contain_file('krb_configuration')
              .with_content(%r{\[libdefaults\]\ndefault_realm = EXAMPLE.COM\n})
          end

          it do
            is_expected.to contain_file('krb_configuration')
              .with_content(%r{dns_lookup_realm = true\n})
          end

          it do
            is_expected.to contain_file('krb_configuration')
              .with_content(%r{dns_lookup_kdc = true\n})
          end

          it do
            is_expected.to contain_file('krb_configuration')
              .with_content(%r{kdc_timesync = 0\n})
          end

          it do
            is_expected.to contain_exec('run_kinit_with_keytab')
              .that_comes_before('Exec[realm_join_with_keytab]')
              .with(
                path: '/usr/bin:/usr/sbin:/bin',
                command: 'kinit -kt /tmp/join.keytab user',
                unless: "klist -k /etc/krb5.keytab | grep -i 'foo@example.com'",
              )
          end

          it do
            is_expected.to contain_exec('realm_join_with_keytab')
              .with(
                path: '/usr/bin:/usr/sbin:/bin',
                command: 'realm join example.com',
                unless: "klist -k /etc/krb5.keytab | grep -i 'foo@example.com'",
              )
          end
        end

        context 'realmd::join::keytab class with custom krb_config' do
          let(:params) do
            super().merge(
              krb_config: {
                'libdefaults' => {
                  'default_realm' => 'EXAMPLE.COM',
                },
                'domain_realm' => {
                  'localhost.example.com' => 'EXAMPLE.COM',
                },
                'realms' => {
                  'EXAMPLE.COM' => {
                    'kdc' => 'dc.example.com:88',
                  },
                },
              },
            )
          end

          it { is_expected.to contain_class('realmd::join::keytab') }

          it do
            is_expected.to contain_file('krb_configuration')
              .with_content(%r{\[domain_realm\]\nlocalhost.example.com = EXAMPLE.COM\n})
          end

          it do
            is_expected.to contain_file('krb_configuration')
              .with_content(%r{\[libdefaults\]\ndefault_realm = EXAMPLE.COM\n})
          end

          it do
            is_expected.to contain_file('krb_configuration')
              .with_content(%r{\[realms\]\nEXAMPLE.COM = \{\n  kdc = dc.example.com:88\n})
          end
        end

        context 'with krb_keytab_source set' do
          let(:params) { super().merge(krb_keytab_source: 'puppet:///foo/bar') }

          it { is_expected.to contain_file('krb_keytab').with_source('puppet:///foo/bar') }
        end

        context 'with krb_keytab_content set' do
          context 'with non-base64-encoded String' do
            let(:params) { super().merge(krb_keytab_content: 'example') }

            it { is_expected.to raise_error(%r{invalid base64}) }
          end

          context 'with base64-encoded String' do
            let(:params) { super().merge(krb_keytab_content: 'ZXhhbXBsZQ==') }

            it { is_expected.to contain_file('krb_keytab').with_content('example') }
          end

          context 'with base64-encoded Sensitive[String]' do
            let(:params) { super().merge(krb_keytab_content: sensitive('ZXhhbXBsZQ==')) }

            it { is_expected.to contain_file('krb_keytab').with_content('example') }
          end

          # Find a way to pass Binary to krb_keytab_content
          # context 'with Binary' do
          # end

          # Find a way to pass Sensitive[Binary] to krb_keytab_content
          # context 'with Sensitive[Binary]' do
          # end
        end

        context 'with manage_krb_keytab => false' do
          let(:params) { super().merge(manage_krb_keytab: false) }

          it { is_expected.not_to contain_file('krb_keytab') }
        end

        context 'with computer_name set' do
          let(:params) { super().merge(computer_name: 'A20CharsComputerName') }

          it do
            is_expected.to contain_exec('run_kinit_with_keytab')
              .with_unless("klist -k /etc/krb5.keytab | grep -i 'A20CharsComputerName@example.com'")
          end

          it do
            is_expected.to contain_exec('realm_join_with_keytab')
              .with_command('realm join example.com --computer-name=A20CharsComputerName')
              .with_unless("klist -k /etc/krb5.keytab | grep -i 'A20CharsComputerName@example.com'")
          end
        end

        context 'with automatic_id_mapping => false' do
          let(:params) { super().merge(automatic_id_mapping: false) }

          it do
            is_expected.to contain_exec('realm_join_with_keytab')
              .with_command('realm join example.com --automatic-id-mapping=no')
          end
        end

        context 'with ou set' do
          let(:params) { super().merge(ou: 'OU=test') }

          it do
            is_expected.to contain_exec('realm_join_with_keytab')
              .with_command('realm join example.com --computer-ou=OU=test')
          end
        end
      end
    end
  end
end
