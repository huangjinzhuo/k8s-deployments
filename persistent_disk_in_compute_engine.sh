#### Persistent Disk for Compute Engine

export ZONE=us-central1-c

# create a VM instance
gcloud compute instances create myinstance --zone=$ZONE

# create a persistent disk
gcloud compute disks create mydisk --size=200GB --zone=$ZONE
# default disk type is pd-strandard

# attach the persistent disk to an instance
gcloud compute instances attach-disk myinstance --disk=mydisk --zone=$ZONE

# finding the disk in the VM instance
ls -l /dev/disk/by-id/
# perform the above command in the VM instance instead of the Cloud Shell. To ssh in the VM:
gcloud compute ssh myinstance --zone=$ZONE
# or connect to the instance by selecting the drop down SSH in Cloud Console.
# the default name of the persistent disk is not mydisk, it's:
# scsi-0Google_PersistentDisk_persistent-disk-1.
# to change the name, name it when you attach the disk:
gcloud compute instances attach-disk myinstance --disk=mydisk --zone=$ZONE --device-name=<DEVICE_NAME_YOU_WANT_TO_SEE_IN_INSTANCE>

# format and mount the persistent disk
sudo mkdir /mnt/mydisk
sudo mkfs.ext4 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/disk/by-id/scsi-0Google_PersistentDisk_persistent-disk-1
sudo mount -o discard,defaults /dev/disk/by-id/scsi-0Google_PersistentDisk_persistent-disk-1 /mnt/mydisk

# automatially mount the disk on instance restart
sudo nano /etc/fstab
# add this under the UUID=... line: /dev/disk/by-id/scsi-0Google_PersistentDisk_persistent-disk-1 /mnt/mydisk ext4 defaults 1 1
# result:
    # UUID=e084c728-36b5-4806-bb9f-1dfb6a34b396 / ext4 defaults 1 1
    # /dev/disk/by-id/scsi-0Google_PersistentDisk_persistent-disk-1 /mnt/mydisk ext4 defaults 1 1