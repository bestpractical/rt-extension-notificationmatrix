use warnings;
use strict;

package RT::Extension::NotificationMatrix;
our $VERSION = '1.6';

RT::Ruleset->Add(
    Name => 'NotificationMatrix',
    Rules => [
        'RT::Extension::NotificationMatrix::Notify',
    ]);

sub get_queue_matrix {
    my ($self, $queue) = @_;

    my $attr = $queue->FirstAttribute('NotificationMatrix');

    $attr ? $attr->Content : {};
}

1;
