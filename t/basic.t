#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;

BEGIN {
    $ENV{LC_ALL} = $ENV{LANG} = 'en_US.UTF-8';
    eval { require Email::Abstract; require Test::Email; 1 }
        or plan skip_all => 'require Email::Abstract and Test::Email';
}

use RT;
use RT::Test tests => 15;
use RT::Test::Email;
RT->Config->Set( LogToScreen => 'debug' );
RT->Config->Set('Plugins',qw(RT::Extension::NotificationMatrix));

use_ok('RT::Extension::NotificationMatrix');

# we need to lie to RT and have it find our templates 
# in the local directory
{ no warnings 'redefine';
  use Cwd 'abs_path';

  my $orig_base = \&RT::Plugin::_BasePath;
  *RT::Plugin::_BasePath = sub {
      my $self = $_[0];
      my $base = $self->{'name'};
      $base =~ s'::'/'g;
      my $lib = abs_path($INC{"$base.pm"});
      $lib =~ s{\Qlib/$base.pm}{} ? $lib : goto $orig_base;
  };
}

my %users;
for my $user_name (qw(user_a user_b user_c)) {
    my $user = $users{$user_name} = RT::User->new($RT::SystemUser);
    $user->Create( Name => uc($user_name),
                   Privileged => 1,
                   EmailAddress => $user_name.'@company.com');
}

my $q = RT::Queue->new($RT::SystemUser);
$q->Load('General');

my %groups;

{
my $group_obj = RT::Group->new($RT::SystemUser);
my ($ret, $msg) = $group_obj->CreateUserDefinedGroup
    ( Name => 'GroupA',
      Description => 'GroupA');
($ret, $msg) = $group_obj->AddMember($users{$_}->PrincipalObj->Id())
    for qw(user_a user_b);
$groups{group_a} = $group_obj;

$group_obj = RT::Group->new($RT::SystemUser);
($ret, $msg) = $group_obj->CreateUserDefinedGroup
    ( Name => 'GroupB',
      Description => 'GroupB');
($ret, $msg) = $group_obj->AddMember($users{$_}->PrincipalObj->Id())
    for qw(user_b user_c);
$groups{group_b} = $group_obj;

$group_obj = RT::Group->new($RT::SystemUser);
$group_obj->LoadSystemInternalGroup('Privileged');
$group_obj->PrincipalObj->GrantRight(Object => $q, Right => $_)
    for (qw(OwnTicket ModifyTicket ShowTicket showticketcomments));

$group_obj->LoadSystemInternalGroup('Everyone');
$group_obj->PrincipalObj->GrantRight(Object => $q, Right => $_)
    for (qw(CreateTicket));

}

# remove all existing notification
my $scrips = RT::Scrips->new($RT::SystemUser);
$scrips->LimitToGlobal;
while (my $sc = $scrips->Next) {
    $sc->Delete;
}

my ($tid, $ttrans, $tmsg);
my $cu = RT::CurrentUser->new;
$cu->Load( $users{user_b} );

my $t = RT::Ticket->new($cu);

# no rules defined, no mail
mail_ok {
    ($tid, $ttrans, $tmsg) =
        $t->Create(Subject => "a test",
                   Owner => "user_a", Requestor => 'user_b',
                   Queue => $q->Id,
                   AdminCc => 'user_c',
               );
    ok($tid);
};

my $Groups = RT::Groups->new($RT::SystemUser);
$Groups->LimitToRolesForQueue($q->Id);

my @groups = @{ $Groups->ItemsArrayRef };

my $owners = RT::Group->new($RT::SystemUser);
$owners->LoadQueueRoleGroup(Queue => $q->Id, Type => 'Owner');

my $requestors = RT::Group->new($RT::SystemUser);
$requestors->LoadQueueRoleGroup(Queue => $q->Id, Type => 'Requestor');

my $admincc = RT::Group->new($RT::SystemUser);
$admincc->LoadQueueRoleGroup(Queue => $q->Id, Type => 'AdminCc');

my $matrix = { TicketCreated => [ $owners->id, $groups{group_a}->id, $requestors->id ],
               TicketTaken   => [ $groups{group_b}->id, $admincc->id ],
               TicketUpdatedExternally => [ $owners->id ],
           };

$q->SetAttribute(Name => 'NotificationMatrix',
                 Description => 'Notification Matrix Internal Data',
                 Content => $matrix);



mail_ok {
    ($tid, $ttrans, $tmsg) =
        $t->Create(Subject => "a test",
                   Requestor => 'user_b',
                   Queue => $q->Id,
                   AdminCc => 'user_c',
               );
    ok($tid);
} { from => qr'USER_B via RT',
    bcc => 'user_a@company.com, user_b@company.com', # from ticket created: group_a
    subject => qr/a test/,
    body => qr/Transaction: Ticket created by USER_B/,
}, { from => qr'USER_B via RT',
    to => 'user_b@company.com',
    subject => qr/a test/,
    body => qr/automatically generated in response/,
};

mail_ok {
    my ($res, $msg) = $t->SetOwner($users{user_b});
    ok($res, $msg);
} { from => qr'USER_B via RT',
    bcc => 'user_b@company.com, user_c@company.com', # from ticket taken: group_b
    subject => qr/a test/,
    body => qr/Given to USER_B/,
};


mail_ok {
    my $cu = RT::CurrentUser->new;
    $cu->Load( $users{user_b} );
    $t->SetCurrentUser($cu);
    my $t2 = RT::Ticket->new($cu);
    $t2->Load($t->id);
    my ($res, $msg) = $t2->Correspond(Content => "foobar");
    ok($res, $msg);
};

mail_ok {
    my $cu = RT::CurrentUser->new;
    $cu->Load( $users{user_a} );
    $t->SetCurrentUser($cu);
    my $t2 = RT::Ticket->new($cu);
    $t2->Load($t->id);
    my ($res, $msg) = $t2->Correspond(Content => "foobar");
    ok($res, $msg);
} { from => qr'USER_A via RT',
    to => 'user_b@company.com',
    subject => qr/a test/,
    body => qr/foobar/,
};


#my ($baseurl, $m) = RT::Test->started_ok;

#diag "$baseurl/?user=root&pass=password"; sleep 1 while 1;

1;

