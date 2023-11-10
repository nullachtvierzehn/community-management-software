import { makeExtendSchemaPlugin, gql } from "postgraphile/utils";
import {
  ExecutableStep,
  FieldArgs,
  access,
  constant,
  context,
  list,
  object,
} from "postgraphile/grafast";
import { withPgClientTransaction } from "postgraphile/@dataplan/pg";

export const MyRegisterUserMutationPlugin = makeExtendSchemaPlugin((build) => {
  const { sql } = build;
  const { users } = build.input.pgRegistry.pgResources;
  const { executor } = users;
  return {
    typeDefs: gql`
      input RegisterUserInput {
        name: String!
        email: String!
        bio: String
      }

      type RegisterUserPayload {
        user: User
        query: Query
      }

      input LoginInput {
        username: String!
        password: String!
      }

      type LoginPayload {
        user: User!
      }

      extend type Mutation {
        registerUser(input: RegisterUserInput!): RegisterUserPayload
        login(input: LoginInput!): LoginPayload
      }
    `,
    plans: {
      Mutation: {
        login(_, fieldArgs) {
          const loginFunction = context().get('login')
          const $input = fieldArgs.getRaw(
            "input"
          ) as unknown as ExecutableStep<{
            username: string;
            password: string;
          }>;

          $input.

          const $user = withPgClientTransaction(executor, list([$input, loginFunction]), async(pgClient, [input, login]) => {
            const { rows: [] } = await pgClient.query({ text: `select * from app_public.users where username = $1`, values: [input.username] })

          })

          users.find({});
        },
        registerUser(_, fieldArgs) {
          const $input = fieldArgs.getRaw(
            "input"
          ) as unknown as ExecutableStep<{
            name: string;
            email: string;
            bio?: string;
          }>;
          const $user = withPgClientTransaction(
            executor,
            $input,
            async (pgClient, input) => {
              // Our custom logic to register the user:
              const {
                rows: [user],
              } = await pgClient.query({
                text: `
                    INSERT INTO app_public.users (name, email, bio)
                    VALUES ($1, $2, $3)
                    RETURNING *`,
                values: [input.name, input.email, input.bio],
              });

              // Send the email. If this fails then the error will be caught
              // and the transaction rolled back; it will be as if the user
              // never registered
              await mockSendEmail(
                input.email,
                "Welcome to my site",
                `You're user ${user.id} - thanks for being awesome`
              );

              // Return the newly created user
              return user;
            }
          );

          // To allow for future expansion (and for the `clientMutationId`
          // field to work), we'll return an object step containing our data:
          return object({ user: $user });
        },
      },

      // The payload also needs plans detailing how to resolve its fields:
      RegisterUserPayload: {
        user($data) {
          const $user = $data.get("user");
          // It would be tempting to return $user here, but the step class
          // is not compatible with the auto-generated `User` type, so
          // errors will occur. We must ensure that we return a compatible
          // step, so we will retrieve the relevant record from the database:

          // Get the '.id' property from $user:
          const $userId = access($user, "id");

          // Return a step representing this row in the database.
          return users.get({ id: $userId });
        },
        query($user) {
          // Anything truthy should work for the `query: Query` field.
          return constant(true);
        },
      },
    },
  };
});
