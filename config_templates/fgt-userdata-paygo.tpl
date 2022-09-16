Content-Type: multipart/mixed; boundary="===============0086047718136476635=="
MIME-Version: 1.0

--===============0086047718136476635==
Content-Type: text/plain; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="config"

config system global
set hostname ${fgt_id}
end
config system admin
edit "admin"
set password ${fgt_admin_password}
set force-password-change disable
set gui-ignore-release-overview-version "7.2.0"
next
end
config system interface
edit port1
set alias public
set mode static
set ip ${Port1IP} ${public_subnet_mask}
set allowaccess ping https ssh fgfm
set mtu-override enable
set mtu 9001
next
edit port2
set alias private
set mode static
set ip ${Port2IP} ${private_subnet_mask}
set allowaccess ping fgfm
set mtu-override enable
set mtu 9001
next
end
config router static
edit 0
set device port1
set gateway ${PublicSubnetRouterIP}
next
edit 0
set device port2
set dst ${security_cidr}
set gateway ${PrivateSubnetRouterIP}
next
end
config firewall address
edit service_object
set type fqdn
set associated-interface port2
set fqdn ${ServiceDNSName}
next
end
config firewall vip
edit "vip_to_endpoint_http"
set type fqdn
set extintf "port1"
set portforward enable
set mapped-addr "service_object"
set extport 8080
set mappedport 80
next
edit "vip_to_endpoint_ssh"
set type fqdn
set extintf "port1"
set portforward enable
set mapped-addr "service_object"
set extport 2222
set mappedport 22
next
edit "vip_to_linux_ssh"
set extintf "port1"
set portforward enable
set mappedip "10.0.1.11"
set extport 2222
set mappedport 22
next
edit "vip_to_linux_http"
set extintf "port1"
set portforward enable
set mappedip "10.0.1.11"
set extport 8080
set mappedport 80
next
end
config firewall policy
edit 0
set name "policy_to_service_endpoint_ssh"
set srcintf "port1"
set dstintf "port2"
set srcaddr "all"
set dstaddr "vip_to_endpoint_ssh"
set action accept
set schedule "always"
set service "ALL"
set logtraffic all
next
edit 0
set name "policy_to_service_endpoint_http"
set srcintf "port1"
set dstintf "port2"
set srcaddr "all"
set dstaddr "vip_to_endpoint_http"
set action accept
set schedule "always"
set service "ALL"
set logtraffic all
next
edit 0
set name "policy_to_linux_80"
set srcintf "port1"
set dstintf "port2"
set srcaddr "all"
set dstaddr "vip_to_linux_http"
set action accept
set schedule "always"
set service "ALL"
set logtraffic all
next
edit 0
set name "policy_to_linux_22"
set srcintf "port1"
set dstintf "port2"
set srcaddr "all"
set dstaddr "vip_to_linux_ssh"
set action accept
set schedule "always"
set service "ALL"
set logtraffic all
next
end
--===============0086047718136476635==--