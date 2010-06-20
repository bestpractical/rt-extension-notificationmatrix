package  RT::Extension::NotificationMatrix::Notify;
use strict;
use warnings;
use List::MoreUtils qw(uniq);
use RT::Action::SendEmail;
use base 'RT::Rule';

sub Prepare {
    my $self = shift;

    my $q = $self->TicketObj->QueueObj;
    my $matrix = RT::Extension::NotificationMatrix->get_queue_matrix($q);

    if (my $t = $matrix->{TicketCreated}) {
        my @recipients = uniq map {
            my $g = RT::Group->new($self->CurrentUser);
            $g->Load($_);
            if ($g->Domain eq 'RT::Queue-Role') {
                $g->LoadTicketRoleGroup( Ticket => $self->TicketObj->Id, Type => $g->Type);
            }
            $g->MemberEmailAddresses
        } @$t;

        if (@recipients) {
            my $template = RT::Template->new($self->CurrentUser);
            $template->Load('Transaction') or die;
            # RT::Action weakens the following, so we need to keep additional references
            my $ref = [RT::Scrip->new($self->CurrentUser),
                       { _Message_ID => 0},
                       $template];
            my $email = RT::Action::SendEmail->new ( Argument => undef,
                                                     CurrentUser => $self->CurrentUser,
                                                     ScripObj => $ref->[0],
                                                     ScripActionObj => $ref->[1],
                                                     TemplateObj => $ref->[2],
                                                     TicketObj => $self->TicketObj,
                                                     TransactionObj => $self->TransactionObj,
                                                 );
            $email->{To} = \@recipients;
            $email->Prepare;
            $self->{__ref} = $ref;
            $self->{__email} = $email;
            return 1;
        }

    }

    return 0;
}

sub Commit {
    my $self = shift;
    if ($self->{__email}) {
        $self->{__email}->Commit;
    }

}

1;
