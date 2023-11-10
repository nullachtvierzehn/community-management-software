import loginInput from "./login-input";
import registrationInput from "./registration-input";

export const jsonSchema = {
  $id: "validations",
  definitions: {
    loginInput,
    registrationInput,
  },
} as const;

export default jsonSchema;
