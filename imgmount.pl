#!/usr/bin/env perl
use strict;
use warnings;

#install
#sudo ln -s $(readlink -f imgmount.pl) /usr/local/bin/imgmount
#sudo ln -s $(readlink -f imgmount.pl) /usr/local/bin/imgumount

my $MOUNT_DIR_PREFIX = '/mnt/imgmount';
my $MAX_MOUNT_PARTITIONS = 10;

if ($0 =~ 'imgmount') {
	my $img = $ARGV[0]
		or usage_mount();

	my ($sector_size, $partitions) = get_img_info($img);
	foreach my $partition (@{ $partitions }) {
		my $partition_offset = $sector_size * $partition->{'start'};
		mount_partition($partition_offset, $img);
	}
	exit 0;
}

#umount
my %busy_mnt_points = get_all_mounts();
for (my $i = 0; $i < $MAX_MOUNT_PARTITIONS; $i++) {
	my $mounted_point = $MOUNT_DIR_PREFIX . $i;
	if ($busy_mnt_points{ $mounted_point }) {
		system("sudo umount $mounted_point");
	}
}
exit 0;

sub get_img_info {
	my ($img) = @_;
	-f $img or usage();

	my $out = system("fdisk --list $img");
	my @out = split("\n", $out);
	my ($sector_size, $now_is_disk_info, @partitions);
	foreach my $str (@out) {
		if ($str =~ /Units: sectors of 1 \* \d+ = (\d+) bytes/x) {
			$sector_size = $1;
			next;
		}
		if ($str =~ /Device\s+Boot\s+Start/x) {
			$now_is_disk_info = 1;
			next;
		}
		if ($now_is_disk_info) {
			#/home/asd/BananaPi/images/bananian-1604.img1       2048   43007   40960   20M 83 Linux
			my %partition;
			@partition{qw(device boot start end sectors size id type)} = $str =~ /
				^([^\s]+)   #device
				([\s*]+)\s+ #boot
				([^\s]+)\s+ #start
				([^\s]+)\s+ #end
				([^\s]+)\s+ #sectors
				([^\s]+)\s+ #size
				([^\s]+)\s+ #id
				([^\s]+)    #type
			$/x;
			$partition{'boot'} =~ s/ //g;
			push @partitions, \%partition;
		}
	}
	$sector_size
		or _die('Sector size not found');

	return $sector_size, \@partitions;
}

sub mount_partition {
	my ($partion_offset, $img) = @_;

	my $mount_point = get_free_mnt_point();
	system("sudo mount -o loop,offset=$partion_offset $img $mount_point");
	return 1;
}

sub get_all_mounts {
	my $out = system("cat /proc/mounts");
	my @out = split("\n", $out);
	my %busy_mnt_points;
	foreach my $str (@out) {
		my ($src, $mnt_point) = $str =~ /^([^\s]+) ([^\s]+)/x;
		$busy_mnt_points{ $mnt_point } = $src;
	}
	return %busy_mnt_points;
}

sub get_free_mnt_point {
	my %busy_mnt_points = get_all_mounts();
	for (my $i = 0; $i < $MAX_MOUNT_PARTITIONS; $i++) {
		my $try_mnt_point = $MOUNT_DIR_PREFIX . $i;
		next if $busy_mnt_points{ $try_mnt_point };
		if (!-d $try_mnt_point) {
			system("sudo mkdir -p $try_mnt_point");
		}
		return $try_mnt_point;
	}
	_die('No more free mount points. Try to increase $MAX_MOUNT_PARTITIONS');
}

sub _die {
	print shift . "\n";
	exit 1;
}

sub usage_mount {
	print "Usage:\n";
	print "$0 <img_file>\n";
	exit 1;
}

sub usage_umount {
	print "Usage:\n";
	print "$0 [path]\n";
	print "if path not specified will umount all previously mounted images\n";
	exit 1;
}
