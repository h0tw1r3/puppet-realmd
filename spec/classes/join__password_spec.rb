require 'spec_helper'

describe 'realmd' do
  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          os_facts
        end

        context 'realmd::join::password class' do
          let(:params) do
            {
              domain_join_user: 'user',
              domain_join_password: 'password',
              domain: 'example.com',
            }
          end

          # Mirrors how it is arranged in hieradata: drop password from EL8+ and Ubuntu jammy|focal
          uses_computer_name = !(
            (os_facts.dig(:os, 'family') == 'RedHat' && os_facts.dig(:os, 'release', 'major').to_i >= 8) ||
            (os_facts.dig(:os, 'name') == 'Ubuntu' && ['focal', 'jammy'].include?(os_facts.dig(:os, 'distro', 'codename')))
          )

          it { is_expected.to contain_class('realmd::join::password') }

          it do
            command = '/usr/libexec/realm_join_with_password realm join example.com --unattended --user=user'
            if uses_computer_name
              is_expected.to contain_exec('realm_join_with_password')
                .with(
                  path:    '/usr/bin:/usr/sbin:/bin',
                  command: command + ' --computer-name=foo',
                  unless:  "klist -k /etc/krb5.keytab | grep -i 'foo@example.com'",
                )
            else
              is_expected.to contain_exec('realm_join_with_password')
                .with(
                  path:    '/usr/bin:/usr/sbin:/bin',
                  command: command,
                  unless:  "klist -k /etc/krb5.keytab | grep -i 'foo@example.com'",
                )
            end
          end

          context 'with password_join_use_computer_name overriding the hiera default' do
            let(:params) do
              {
                domain_join_user:                'user',
                domain_join_password:            'password',
                domain:                          'example.com',
                password_join_use_computer_name: !uses_computer_name,
              }
            end

            it do
              command = '/usr/libexec/realm_join_with_password realm join example.com --unattended --user=user'
              if uses_computer_name
                is_expected.to contain_exec('realm_join_with_password')
                  .with_command(command)
              else
                is_expected.to contain_exec('realm_join_with_password')
                  .with_command(command + ' --computer-name=foo')
              end
            end
          end
        end
      end
    end
  end
end
