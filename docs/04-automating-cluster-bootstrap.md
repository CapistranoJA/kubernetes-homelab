# Automating Cluster Bootstrap

## Pain points of previous setup

Before I start, the OS hosting the vms have been migrated from Windows to Fedora. 

Provisioning the vms in this project manually meant creating each VM by hand through vmware then SSHing into every node one by one to set up networking, hostnames, and base packages. This didn't scale once the cluster grew past a couple of nodes, and it wasn't reproducible either, if a node broke and needed to be rebuilt, there was no record of how it was actually configured the first time around. Any drift between nodes had to be caught manually instead of just not happening in the first place.

## Provider Setup


## Defining the VM Resources

## Cloud-Init Integration

## End-to-End Provisioning Flow

## Verification