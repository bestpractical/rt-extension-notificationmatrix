package RT::Extension::NotificationMatrix::Rule::TicketTaken;
use strict;
use warnings;
use base 'RT::Extension::NotificationMatrix::Rule';

use constant NM_Entry => 'TicketTaken';
use constant Description => 'When ticket is taken';

sub ConditionMatched {
    my $self = shift;
    my $txn = $self->TransactionObj;

    return ($txn->Field && $txn->Field eq 'Owner' && $txn->OldValue == $RT::Nobody->Id)
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
