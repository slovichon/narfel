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
package PerlPanel::Applet::IconBar;
use vars qw($ICON_DIR $LAUNCHER_EDITOR $OBJECT_REF);
use Gtk2::SimpleList;
use strict;

our $ICON_DIR = sprintf('%s/share/pixmaps', $PerlPanel::PREFIX);

chomp (our $LAUNCHER_EDITOR = `which perlpanel-item-edit 2> /dev/null`);

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	our $OBJECT_REF = $self;
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::HBox->new;
	$self->widget->set_spacing(PerlPanel::spacing);

	$self->{icondir} = sprintf('%s/.%s/icons', $ENV{HOME}, lc($PerlPanel::NAME));
	unless (-e $self->{icondir}) {
		mkdir(sprintf('%s/.%s', $ENV{HOME}, lc($PerlPanel::NAME)));
		mkdir($self->{icondir});
	}

	$self->load_icons;

	$self->widget->show_all;

	return 1;
}

sub load_icons {
	my $self = shift;

	opendir(DIR, $self->{icondir});
	my @icons = grep { /\.desktop$/i } readdir(DIR);
	closedir(DIR);

	@{$self->{icons}} = ();

	if (scalar(@icons) < 1) {
		$self->widget->pack_start(Gtk2::Label->new(_('The IconBar applet is deprecated, use a Launcher instead!')), 0, 0, 0);

	} else {
		foreach my $file (sort @icons) {
			my $filename = sprintf("%s/%s", $self->{icondir}, $file);
			$self->add_icon(PerlPanel::Applet::IconBar::DesktopEntry->new($filename));
		}
	}

	$self->widget->show_all;

	return 1;
}

sub add_icon {
	my ($self, $entry) = @_;
	push(@{$self->{icons}}, $entry);
	$self->widget->pack_start($entry->widget, 0, 0, 0);
	return 1;
}

sub widget {
	return $_[0]->{widget};
}

sub expand {
	return 0;
}

sub fill {
	return 1;
}

sub end {
	return 'start';
}

sub get_default_config {
	return undef;
}

sub reorder_window {
	my $self = shift;
	my $dialog = Gtk2::Dialog->new;
	$dialog->set_title(_('Reorder Icons'));
	$dialog->set_default_size(250, 200);
	$dialog->set_has_separator(0);
	$dialog->add_buttons('gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
	my $list = Gtk2::SimpleList->new(
		'Icon'	=> 'pixbuf',
		'Name'	=> 'text',
		file	=> 'text',
	);
	$list->get_column(2)->set_visible(0);
	foreach my $icon (@{$self->{icons}}) {
		push(@{$list->{data}}, [$icon->{pixbuf}, $icon->{name}, $icon->{filename}]);
	}
	$list->set_headers_visible(1);
	$list->set_reorderable(1);
	my $scrwin = Gtk2::ScrolledWindow->new;
	$scrwin->set_policy('never', 'automatic');
	$scrwin->set_shadow_type('etched_in');
	$scrwin->set_border_width(6);
	$scrwin->add($list);
	$dialog->vbox->pack_start($scrwin, 1, 1, 0);
	$dialog->signal_connect('response', sub {
		if ($_[1] eq 'ok') {
			my $now = time();
			for (my $i = 0 ; $i < scalar(@{$list->{data}}) ; $i++) {
				my $src_filename = @{@{$list->{data}}[$i]}[2];
				my $dst_filename = sprintf('%s/%d.desktop', $self->{icondir}, $now + $i);
				rename($src_filename, $dst_filename);
			}
		}
		$dialog->destroy;
		if ($_[1] eq 'ok') {
			map { $self->widget->remove($_) } $self->widget->get_children;
			$self->load_icons;
		}
	});
	$dialog->show_all;
	return 1;
}

package PerlPanel::Applet::IconBar::DesktopEntry;
use PerlPanel::DesktopEntry;
use Gtk2::Helper;
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	$self->{filename}	= shift;
	$self->{icondir}	= sprintf('%s/.%s/icons', $ENV{HOME}, lc($PerlPanel::NAME));
	chomp($self->{nautilus}	= `which nautilus 2> /dev/null`);
	bless($self, $self->{package});
	$self->parse unless ($self->{filename} eq 'dummy');

	$self->{widget} = Gtk2::Button->new;
	$self->widget->set_border_width(0);
	$self->widget->set_relief('none');

	$self->build;

	$self->widget->signal_connect('button_release_event', sub {
		# this mess reconciles the behaviour of 'button_release_event' with the expected behaviour, which
		# should be that of 'clicked'. The clicked() method is only called if the mouse pointer is within
		# the widget (get_pointer() returns the co-ords of the pointer relative to the top left corner of
		# the widget):
		my ($mouse_pos_x, $mouse_pos_y) = $self->widget->get_pointer;
		my $widget_size_x = $self->widget->size_request->width;
		my $widget_size_y = $self->widget->size_request->height;
		if (
			$mouse_pos_x <= $widget_size_x &&
			$mouse_pos_y <= $widget_size_y &&
			$mouse_pos_x > -1 &&
			$mouse_pos_y > -1	

		) {
			$self->clicked($_[1]->button);
		}
		return undef;
	});

	return $self;
}

sub parse {
	my $self = shift;
	$self->{entry} = PerlPanel::DesktopEntry->new($self->{filename});
	return 1;
}

sub build {
	my $self = shift;
	if (-e $self->{entry}->Icon) {
		$self->{iconfile} = $self->{entry}->Icon;

	} else {
		$self->{iconfile} = PerlPanel::lookup_icon($self->{entry}->Icon);

	}
	if (-e $self->{iconfile}) {
		$self->{pixbuf} = Gtk2::Gdk::Pixbuf->new_from_file_at_size($self->{iconfile}, PerlPanel::icon_size, PerlPanel::icon_size);
		$self->{pixmap} = Gtk2::Image->new_from_pixbuf($self->{pixbuf});

	} else {
		my $pbf = $PerlPanel::OBJECT_REF->panel->render_icon('gtk-missing-image', 'dialog')->scale_simple(PerlPanel::icon_size, PerlPanel::icon_size, 'bilinear');
		$self->{pixmap} = Gtk2::Image->new_from_pixbuf($pbf);

	}

	$self->{pixmap}->set_size_request(PerlPanel::icon_size, PerlPanel::icon_size);

	$self->widget->add($self->{pixmap});
	$self->widget->show_all;

	my $tip = $self->{entry}->Name(PerlPanel::locale) || $self->{entry}->Exec;
	$tip .= "\n".$self->{entry}->Comment(PerlPanel::locale) if ($self->{entry}->Comment(PerlPanel::locale) ne '');
	PerlPanel::tips->set_tip($self->widget, $tip);

	return 1;
}

sub widget {
	return $_[0]->{widget};
}

sub clicked {
	my ($self, $button) = @_;
	$self->widget->grab_focus;
	if ($button == 1) {
		PerlPanel::launch($self->{entry}->Exec, $self->{entry}->StartupNotify);
	} elsif ($button == 3) {
		if (!defined($self->{menu})) {
			$self->{itemfactory} = [
				[
					'/',
					undef,
					undef,
					undef,
					'<Branch>',
				],
				[
					'/'._('Delete...'),
					undef,
					sub { $self->delete },
					undef,
					'<StockItem>',
					'gtk-remove',
				],
				[
					'/'._('Edit...'),
					undef,
					sub { $self->edit },
					undef,
					'<StockItem>',
					'gtk-properties',
				],
				[
					'/'._('Add...'),
					undef,
					sub { $self->add },
					undef,
					'<StockItem>',
					'gtk-add',
				],
				[
					'/'._('Reorder...'),
					undef,
					sub { $PerlPanel::Applet::IconBar::OBJECT_REF->reorder_window },
					undef,
					'<StockItem>',
					'gtk-index',
				],
			];
			if (-x $self->{nautilus}) {
				push(
					@{$self->{itemfactory}},
					[
						'/Separator',
						undef,
						undef,
						undef,
						'<Separator>',
					],
					[
						'/'._('View Icon Directory'),
						undef,
						sub { system("$self->{nautilus} --no-desktop $self->{icondir} &") },
						undef,
						'<StockItem>',
						'gtk-open'
					],
				);
			}
			$self->{factory} = Gtk2::ItemFactory->new('Gtk2::Menu', '<main>', undef);
			$self->{factory}->create_items(@{$self->{itemfactory}});
			$self->{menu} = $self->{factory}->get_widget('<main>');
		}
		$self->{menu}->popup(undef, undef, sub { return $self->popup_position(@_) }, 0, $self->widget, undef);
	}
	return 1;
}

sub popup_position {
	my $self = shift;
	my ($x0, undef) = PerlPanel::get_widget_position($self->widget);
	if (PerlPanel::position eq 'top') {
		return ($x0, PerlPanel::panel->allocation->height);
	} else {
		$self->{menu}->realize;
		$self->{menu}->show_all;
		return ($x0, PerlPanel::screen_height() - $self->{menu}->allocation->height - PerlPanel::panel->allocation->height);
	}
}

sub edit {
	my $self = shift;
	if (-x $LAUNCHER_EDITOR) {
		my $mtime = (stat($self->{filename}))[9];
		$self->widget->set_sensitive(0);
		PerlPanel::exec_wait("$LAUNCHER_EDITOR $self->{filename}", sub {
			$self->widget->set_sensitive(1);

			my $newmtime = (stat($self->{filename}))[9];

			if ($newmtime > $mtime) {
				$self->parse;
				$self->widget->remove($self->widget->child);
				$self->build;
				PerlPanel::save_config;
			}
		});
	} else {
		PerlPanel::warning(_('No desktop item editor could be found.'));
	}
	return 1;
}

sub add {
	my $self = shift;
	my $filename = sprintf('%s/.%s/icons/%d.desktop', $ENV{HOME}, lc($PerlPanel::NAME), time());
	if (-x $LAUNCHER_EDITOR) {
		open(FILE, ">$filename") && close(FILE);
		my $mtime = time();
		PerlPanel::exec_wait("$LAUNCHER_EDITOR $filename", sub {
			my $newmtime = (stat($filename))[9];

			if ($newmtime > $mtime) {
				my $widget = PerlPanel::Applet::IconBar::DesktopEntry->new($filename)->widget;
				$widget->show_all;
				$self->widget->parent->pack_start($widget, 0, 0, 0);
				PerlPanel::save_config;

			} else {
				# nothing changed - delete the file:
				unlink($filename);
			}
		});
	} else {
		PerlPanel::warning(_('No desktop item editor could be found.'));
	}
	return 1;
}

sub delete {
	my $self = shift;
	unlink($self->{filename});
	$self->widget->parent->remove($self->widget);
	return 1;
}

1;
