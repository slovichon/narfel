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
package PerlPanel::Applet::Commander;
use File::Basename qw(basename);
use vars qw($iconfile);
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my ($self, $opt) = @_;
	if ($opt ne 'no-widget') {
		$self->{widget} = Gtk2::Button->new;
		$self->widget->set_relief('none');
		$self->widget->add(Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('commander', PerlPanel::icon_size)));
		$self->widget->signal_connect('clicked', sub { $self->run });
		PerlPanel::tips->set_tip($self->widget, _('Run Command'));
		$self->widget->show_all;
	}
	our $iconfile = PerlPanel::get_applet_pbf_filename('commander');
	$self->{store} = $self->create_store;
	return 1;
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

sub run {
	my $self = shift;

	my @history = PerlPanel::get_run_history;

	my $default_pbf = Gtk2::Gdk::Pixbuf->new_from_file($iconfile);

	my $icon = Gtk2::Image->new_from_pixbuf($default_pbf);
	my $icon_alignment = Gtk2::Alignment->new(0.5, 0.5, 1, 1);
	$icon_alignment->add($icon);

	my $command_entry = Gtk2::Combo->new;
	$command_entry->disable_activate;
	$command_entry->set_popdown_strings('', @history);
	$command_entry->set_use_arrows(1);
	$command_entry->list->select_item(0);

	my $completion = Gtk2::EntryCompletion->new;
	$completion->set_model($self->{store});
	$completion->set_text_column(0);
	$completion->set_minimum_key_length(2);
	$command_entry->entry->set_completion($completion);

	$command_entry->entry->signal_connect('changed', sub {
		my ($command, undef) = split(/\s/, $command_entry->entry->get_text, 2);
		if ($command eq '') {
			$icon->set_from_pixbuf($default_pbf);
		} else {
			my $icon_file = PerlPanel::lookup_icon(basename($command));
			if (-e $icon_file) {
				my $new_pbf = Gtk2::Gdk::Pixbuf->new_from_file_at_size($icon_file, $default_pbf->get_width, $default_pbf->get_height);
				$icon->set_from_pixbuf($new_pbf);
			} else {
					$icon->set_from_pixbuf($default_pbf);
			}
		}
	});

	my $terminal_checkbutton = Gtk2::CheckButton->new(_('Run in terminal'));

	my $file_button = Gtk2::Button->new(_('Run with file...'));
	$file_button->signal_connect('clicked', sub {
		my $file_selection;
		if ('' ne (my $msg = Gtk2->check_version (2, 4, 0)) or $Gtk2::VERSION < 1.040) {
			$file_selection = Gtk2::FileSelection->new(_('Choose File'));
		} else {
			$file_selection = Gtk2::FileChooserDialog->new(
				_('Choose File'),
				undef,
				'open',
				'gtk-cancel'	=> 'cancel',
				'gtk-ok' => 'ok'
			);
		}
		$file_selection->signal_connect('response', sub {
			if ($_[1] eq 'ok') {
				my $file = $file_selection->get_filename;
				if ($file !~ /^([A-Za-z0-9\_\-\.])$/) {
					$file = "'$file'";
				}
				$command_entry->entry->set_text($command_entry->entry->get_text . ' ' . $file);
			}
			$file_selection->destroy;
		});
		$file_selection->run;
		return 1;
	});

	my $hbox = Gtk2::HBox->new;
	$hbox->set_spacing(12);
	$hbox->pack_start($terminal_checkbutton, 1, 1, 0);
	$hbox->pack_start($file_button, 0, 0, 0);

	my $vbox = Gtk2::VBox->new;
	$vbox->set_spacing(6);
	$vbox->pack_start($command_entry, 0, 0, 0);
	$vbox->pack_start($hbox, 1, 1, 0);

	my $main_hbox = Gtk2::HBox->new;
	$main_hbox->set_border_width(5);
	$main_hbox->set_spacing(6);
	$main_hbox->pack_start($icon_alignment, 0, 0, 0);
	$main_hbox->pack_start($vbox, 1, 1, 0);

	my $dialog = Gtk2::Dialog->new;
	$dialog->set_title(_('Run Command'));
	$dialog->set_position('center');
	$dialog->set_resizable(0);
	$dialog->set_border_width(5);
	$dialog->set_has_separator(0);
	$dialog->set_skip_pager_hint(1);
	$dialog->set_skip_taskbar_hint(1);
	$dialog->set_icon($icon->get_pixbuf);
	$dialog->add_buttons('gtk-cancel' => 'cancel', 'gtk-execute' => 'ok');
	$dialog->action_area->set_layout('end');
	$dialog->vbox->pack_start($main_hbox, 1, 1, 0);
	$dialog->signal_connect('response', sub {
		# wondering why we're doing an 'eq' for a int? because strings 
		# evaluate to 0:
		if ($_[1] eq 'ok' || $_[1] eq 0) {
			my $command = $command_entry->entry->get_text;
			if ($terminal_checkbutton->get_active) {
				$command = 'xterm -e '.$command;
			}
	
			PerlPanel::append_run_history($command);

			chdir($ENV{HOME});
			system("$command &");
		}
		if (!defined($PerlPanel::OBJECT_REF)) {
			# we're not in a panel, so we can just quit:
			exit;
		} else {
			$dialog->destroy;
		}
	});

	$command_entry->entry->signal_connect('activate', sub { $dialog->signal_emit('response', 'ok') });

	$dialog->show_all;

	return 1;
}

sub create_store {
	my $self = shift;
	my $store = Gtk2::ListStore->new(Glib::String::);

	my %executables;
	foreach my $dir (split(/:/, $ENV{PATH})) {
		if (!opendir(DH, $dir)) {
			next;
		} else {
			my @files = grep { -x "$dir/$_" } grep { ! /^\.{1,2}$/ } readdir(DH);
			closedir(DH);
			map { $executables{$_}++ } @files;
		}
	}

	foreach my $program (sort keys %executables) {
		$store->set($store->append, 0, $program);
	}

	return $store;
}

1;
