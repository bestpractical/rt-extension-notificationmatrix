package RT::Extension::NotificationMatrix::Rule::TicketTaken;
use strict;
use warnings;
use base 'RT::Extension::NotificationMatrix::Rule';

use constant NM_Entry => 'TicketTaken';

sub ConditionMatched {
    my $self = shift;
    my $txn = $self->TransactionObj;

    return ($txn->Field && $txn->Field eq 'Owner' && $txn->OldValue == $RT::Nobody->Id)
}

1;
