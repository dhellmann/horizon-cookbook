########################################################################
# Toggles - These can be overridden at the environment level
default["enable_monit"] = false  # OS provides packages
default["developer_mode"] = false  # we want secure passwords by default
########################################################################

default["openstack"]["horizon"]["folsom"]["version"] = "2012.2+git201209242000~precise-0ubuntu1"

default["openstack"]["horizon"]["db"]["name"] = "horizon"
default["openstack"]["horizon"]["db"]["username"] = "horizon"

# Account for the moving target that is the dashboard path....
default["openstack"]["horizon"]["dash_path"] = "/usr/share/openstack-dashboard/openstack_dashboard"
default["openstack"]["horizon"]["wsgi_path"] = node["openstack"]["horizon"]["dash_path"] + "/wsgi"
