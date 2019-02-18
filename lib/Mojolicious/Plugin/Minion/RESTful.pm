package Mojolicious::Plugin::Minion::RESTful;

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::File 'path';
 
use Digest::MD5;

sub register {
    my ($self, $app, $config) = @_;
    
    # Config
    my $prefix = $config->{route} // $app->routes->any('/minion/api');
    $prefix->to(return_to => $config->{return_to} // '/');
    
    # Static files

    my $resources = path(__FILE__)->sibling('resources');

    push @{$app->static->paths}, $resources->child('public')->to_string;
    
    # Templates
    push @{$app->renderer->paths}, $resources->child('templates')->to_string;
    
    # Routes
    $prefix->get('/tasks' => sub {
		     my $c = shift;
		     $c->stash('tasks', [ sort keys %{$c->minion->tasks} ]);
		     $c->render(template => 'tasks');
		 });

    $prefix->get('/upload/:task' => sub {
		     my $c = shift;
		     $c->render(template => 'upload');
		 });

    $prefix->get('/status/:nr/view' => sub {
		     my $c = shift;
		     $c->render(template => 'status');
		 })->name('get_job_status_page');

    $prefix->any('/status/:nr' => sub {
		     my $c = shift;
		     my $job = $c->minion->job($c->param('nr'));
		     my $json; for (qw/state created attempts id/) { $json->{$_} = $job->info->{$_} };
		     $c->render(json => $json);
		 })->name('get_job_status');

    $prefix->get('/status/:nr/result' => sub {
		     my $c = shift;
		     my $job = $c->minion->job($c->param('nr'));
		     $c->res->headers->content_type($job->info->{result}->{type});
		     $c->render(data => $job->info->{result}->{content});
		 })->name('get_job_result');; 

    $prefix->post('/do/:task' => sub {
		      my $c = shift;
		      
		      my $j = $c->minion->enqueue($c->param('task'), [ $c->req->body ]);
		      
		      my $ctx = Digest::MD5->new;
		      
		      $ctx->add($c->req->body);

		      my $hex = $ctx->hexdigest;
		      $c->app->log->debug(length $c->req->body);
		      $c->app->log->debug($hex);
		      
		      my $job = $c->minion->job($j);
		      
		      my $json; for (qw/state created attempts id result/) { $json->{$_} = $job->info->{$_} };
		      
		      $json->{size} = $c->req->body_size;
		      $json->{md5}  = $hex;
		      
		      $c->render(json => $json);
		  })->name('start_job');
}

1;
