CREATE SCHEMA "users";
--> statement-breakpoint
CREATE SCHEMA "organizations";
--> statement-breakpoint
CREATE TABLE "users"."users" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"kind" text NOT NULL,
	"username" text NOT NULL,
	"status" text DEFAULT 'active' NOT NULL,
	CONSTRAINT "users_username_unique" UNIQUE("username")
);
--> statement-breakpoint
CREATE TABLE "users"."humans" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"legal_name" text,
	"birth_date" date,
	"age_group" text NOT NULL,
	"locale" text NOT NULL,
	"region" text
);
--> statement-breakpoint
CREATE TABLE "organizations"."organizations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"kind" text NOT NULL,
	"name" text NOT NULL,
	"slug" text NOT NULL,
	"created_by" uuid NOT NULL,
	"requires_two_step" boolean DEFAULT true NOT NULL,
	"status" text DEFAULT 'active' NOT NULL,
	CONSTRAINT "organizations_slug_unique" UNIQUE("slug")
);
--> statement-breakpoint
CREATE TABLE "organizations"."teams" (
	"organization_id" uuid PRIMARY KEY NOT NULL
);
--> statement-breakpoint
ALTER TABLE "users"."humans" ADD CONSTRAINT "humans_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "users"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "organizations"."organizations" ADD CONSTRAINT "organizations_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "users"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "organizations"."teams" ADD CONSTRAINT "teams_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "organizations"."organizations"("id") ON DELETE cascade ON UPDATE no action;