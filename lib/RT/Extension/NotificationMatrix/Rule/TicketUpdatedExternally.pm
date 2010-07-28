package RT::Extension::NotificationMatrix::Rule::TicketUpdatedExternally;
use strict;
use warnings;
use base 'RT::Extension::NotificationMatrix::Rule';

use constant NM_Entry => 'TicketUpdatedExternally';
use constant DefaultTemplate => 'Admin Correspondence';
use constant DefaultExternalTemplate => 'Correspondence';
use constant Description => 'When ticket is updated externally';

sub ConditionMatched {
    my $self = shift;
    return unless $self->ScripConditionMatched("On Correspond");

    my @groups = ((map { my $g = RT::Group->new($self->CurrentUser);
                         $g->LoadQueueRoleGroup(Queue => $self->TicketObj->QueueObj->Id, Type => $_);
                         $g;
                   } qw(Cc Owner)),
                  (map { my $g = RT::Group->new($self->CurrentUser);
                         $g->LoadTicketRoleGroup(Ticket => $self->TicketObj->Id, Type => $_);
                         $g;
                     } qw(Cc Owner)));

    for (@groups) {
        return if $_->HasMember($self->TransactionObj->CreatorObj->PrincipalId);
    }

    return 1;
}

=head Templates

For external notification, the first template found will be used:

=over

=item TicketUpdatedExternally

=item Correspondence

=item Transaction

=back

For internal notification, the first template found will be used:

=over

=item TicketUpdatedExternally

=item Admin Correspondence

=item Transaction

=back

=cut

1;
