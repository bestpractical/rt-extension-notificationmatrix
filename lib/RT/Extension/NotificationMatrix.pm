use warnings;
use strict;

package RT::Extension::NotificationMatrix;
our $VERSION = '2.1';

RT::Ruleset->Add(
    Name => 'NotificationMatrix',
    Rules => [
        'RT::Extension::NotificationMatrix::Rule::TicketCreated',
        'RT::Extension::NotificationMatrix::Rule::TicketCommented',
        'RT::Extension::NotificationMatrix::Rule::TicketRepliedTo',
        'RT::Extension::NotificationMatrix::Rule::TicketTaken',
        'RT::Extension::NotificationMatrix::Rule::TicketResolved',
        'RT::Extension::NotificationMatrix::Rule::TicketUpdatedExternally',
        'RT::Extension::NotificationMatrix::Rule::QueueChanged',
    ]);

sub get_queue_matrix {
    my ($self, $queue) = @_;

    my $attr = $queue->FirstAttribute('NotificationMatrix');

    $attr ? $attr->Content : {};
}

1;

=head1 NAME

RT::Extension::NotificationMatrix - RT Extension for custom ticket notification

=head1 SYNOPSIS

  # In your RT site config:
  Set(@Plugins,(qw(RT::Extension::NotificationMatrix));
  # If you'd like to Bcc all recipients, uncomment the line below.
  # Disabled by default.
  #Set($NotificationMatrixAlwaysBcc, 1);

=head1 DESCRIPTION

This plugin provides per-queue configuration for notification
triggering based on ticket actions, and notification delivery for
selected ticket roles and/or user-defined groups.

Note that this plugin can co-exist with the L<RT::Scrip>-based
notification, which you probably want to disable to avoid duplicated
messages.

When the plugin is enabled, you will have an additional
C<Notification> tab in the queue admin page.  When a notification rule
is triggered, the designated ticket roles or user defined groups get a
message with the first found template of:

=over

=item $RuleName

For example: TicketResolved

=item The default tempalte defined by the rule

=item The C<Transaction> template

=back

Message sent to external recipients (requestors and ccs) will be using
first found template of:

=over

=item $RuleName-External

For example: TicketResolved-External

=item The default external tempalte defined by the rule

=item The C<Transaction> template

=back

=head1 CAVEATS

Internally, the matrix is stored on the queue object as attributes,
with mappings to the subscribe L<RT::Group> object ids.  The role
groups are stored as queue-role groups, as at the time of
configuration we do not have ticket instances to create ticket-role
groups.  The queue-role gorups are then instantiated as ticket-role
when the notification rules are triggered.

=cut
