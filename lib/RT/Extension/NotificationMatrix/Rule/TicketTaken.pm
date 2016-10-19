package RT::Extension::NotificationMatrix::Rule::TicketTaken;
use strict;
use warnings;
use base 'RT::Extension::NotificationMatrix::Rule';

use constant NM_Entry => 'TicketTaken';
use constant Description => 'When owner is changed';

sub ConditionMatched {
    my $self = shift;
    my $txn = $self->TransactionObj;

    # Limit to Set so we don't notify on a SetWatcher transaction
    return ($txn->Field && $txn->Field eq 'Owner' && $txn->Type eq 'Set' && $txn->OldValue != $txn->NewValue)
}

=head Templates

For external notification, the first template found will be used:

=over

=item TicketTaken-External

=item Transaction

=back

For internal notification, the first template found will be used:

=over

=item TicketTaken

=item Transaction

=back

=cut

1;
