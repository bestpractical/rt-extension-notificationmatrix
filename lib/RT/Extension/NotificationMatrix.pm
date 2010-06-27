use warnings;
use strict;

package RT::Extension::NotificationMatrix;
our $VERSION = '1.6';

RT::Ruleset->Add(
    Name => 'NotificationMatrix',
    Rules => [
        'RT::Extension::NotificationMatrix::Rule::TicketCreated',
        'RT::Extension::NotificationMatrix::Rule::TicketCommented',
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
