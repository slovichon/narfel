# $Id$
# This file is part of PerlPanel.
# 
# PerlPanel is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# PerlPanel is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with PerlPanel; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# Copyright: (C) 2003-2004 Gavin Brown <gavin.brown@uk.com>
#
package PerlPanel::Applet::XMMS;
use vars qw(%TOOLTIPS %CALLBACKS $ICON_DIR $SLIDER_SIZE);
use strict;

our %TOOLTIPS = (
	prev	=> _('Play Previous Track'),
	stop	=> _('Stop Playing'),
	play	=> _('Play'),
	pause	=> _('Pause'),
	next	=> _('Play Next Track'),
);

our %CALLBACKS = (
	prev	=> sub { $_[0]->{controller}->playlist_prev },
	stop	=> sub { $_[0]->{controller}->stop },
	play	=> sub { if ($_[0]->{controller}->is_playing) { $_[0]->{controller}->pause } else { $_[0]->{controller}->play }},
	next	=> sub { $_[0]->{controller}->playlist_next },
);

our $ICON_DIR = sprintf('%s/share/%s/applets/xmms', $PerlPanel::PREFIX, lc($PerlPanel::NAME));

our $SLIDER_SIZE = 150;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	my $loaded = 0;
	eval('use Xmms::Remote; $loaded = 1');
	if ($loaded == 0) {
		PerlPanel::warning(_('The XMMS applet requires the Xmms-Perl module!'));
		return undef;
	} else {
		return $self;
	}
}

#
# A brief note on how the volume controller works:
#
# We can use the 'value-changed' signal to monitor changes to the slider, but
# this introduces a jitter that makes it slightly useless. instead, we place
# the value into volume_pending and set the volume_slider_at_rest to 0.
#
# The timeout callback does the setting of the volume - it will do so when
# the volume_slider_at_rest is 1  and volume_pending is defined.
#
sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::HBox->new;
	$self->{controller} = Xmms::Remote->new;
	$self->{pbfs}{pause} = Gtk2::Gdk::Pixbuf->new_from_file_at_size(sprintf('%s/%s.png', $ICON_DIR, 'pause'), PerlPanel::icon_size, PerlPanel::icon_size);
	foreach my $name (qw(prev play stop next)) {
		$self->{buttons}{$name} = $self->create_button($name);
		my $func = $CALLBACKS{$name};
		$self->{buttons}{$name}->signal_connect('clicked', sub { &$func($self) });
		PerlPanel::tips->set_tip($self->{buttons}{$name}, $TOOLTIPS{$name});
		$self->{widget}->pack_start($self->{buttons}{$name}, 0, 0, 0);
	}
	PerlPanel::add_timeout(50, sub {
		my $running = 0;
		eval('$running = ($self->{controller}->is_running ? 1 : 0)');
		if ($running == 0) {
			$self->widget->set_sensitive(0);
		} elsif (defined($self->{buttons}{play}) && defined($self->{buttons}{play}->child)) {
			$self->widget->set_sensitive(1);
			if ($self->{controller}->is_playing) {
				$self->{buttons}{stop}->set_sensitive(1);
				if ($self->{controller}->is_paused) {
					$self->{buttons}{play}->child->set_from_pixbuf($self->{pbfs}{play});
					PerlPanel::tips->set_tip($self->{buttons}{play}, $TOOLTIPS{play});
				} else {
					$self->{buttons}{play}->child->set_from_pixbuf($self->{pbfs}{pause});
					PerlPanel::tips->set_tip($self->{buttons}{play}, $TOOLTIPS{pause});
				}
			} else {
				$self->{buttons}{stop}->set_sensitive(0);
				$self->{buttons}{play}->child->set_from_pixbuf($self->{pbfs}{play});
			}
			return 1;
		}
	});
	$self->widget->show_all;
	return 1;
}

sub create_button {
	my ($self, $id) = @_;
	$self->{pbfs}{$id} = Gtk2::Gdk::Pixbuf->new_from_file_at_size(sprintf('%s/%s.png', $ICON_DIR, $id), PerlPanel::icon_size, PerlPanel::icon_size);
	my $button = Gtk2::Button->new;
	my $image = Gtk2::Image->new_from_pixbuf($self->{pbfs}{$id});
	$button->set_relief('none');
	$button->add($image);
	return $button;
}

sub widget {
	return $_[0]->{widget};
}

sub expand {
	return 0;
}

sub fill {
	return 0;
}

sub end {
	return 'end';
}

sub get_default_config {
	return undef;
}

1;
