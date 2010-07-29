package RT::Extension::NotificationMatrix::Rule::TicketRepliedTo;
use strict;
use warnings;
use base 'RT::Extension::NotificationMatrix::Rule';

use constant NM_Entry => 'When a ticket is replied to';
use constant DefaultTemplate => 'Admin Correspondence';
use constant DefaultExternalTemplate => 'Correspondence';
use constant Description => 'When a ticket is replied to';

sub ConditionMatched {
    my $self = shift;
    return $self->ScripConditionMatched("On Correspond");
}

=head Templates

For external notification, the first template found will be used:

=over

=item Correspondence

=item Transaction

=back

For internal notification, the first template found will be used:

=over

=item Admin Correspondence

=item Transaction

=back

=cut

1;
