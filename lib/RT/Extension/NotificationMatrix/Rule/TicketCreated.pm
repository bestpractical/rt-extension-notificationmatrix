package RT::Extension::NotificationMatrix::Rule::TicketCreated;
use strict;
use warnings;
use base 'RT::Extension::NotificationMatrix::Rule';

use constant NM_Entry => 'TicketCreated';

use constant Description => 'When ticket is created';
use constant DefaultExternalTemplate => 'AutoReply';

sub ConditionMatched {
    my $self = shift;
    $self->ScripConditionMatched("On Create");
}

=head Templates

For external notification, the first template found will be used:

=over

=item TicketCreated-External

=item AutoReply

=item Transaction

=back

For internal notification, the first template found will be used:

=over

=item TicketCreated

=item Transaction

=back

=cut

1;
