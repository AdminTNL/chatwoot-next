import { required, minLength } from '@vuelidate/validators';

export const getLabelGroupNameErrorMessage = validation => {
  let errorMessage = '';
  if (!validation.name.$error) {
    errorMessage = '';
  } else if (!validation.name.required) {
    errorMessage = 'LABEL_GROUP_MGMT.FORM.NAME.REQUIRED_ERROR';
  } else if (!validation.name.minLength) {
    errorMessage = 'LABEL_GROUP_MGMT.FORM.NAME.MINIMUM_LENGTH_ERROR';
  }
  return errorMessage;
};

export const getLabelGroupTeamErrorMessage = validation => {
  let errorMessage = '';
  if (!validation.selectedTeamId.$error) {
    errorMessage = '';
  } else if (!validation.selectedTeamId.required) {
    errorMessage = 'LABEL_GROUP_MGMT.FORM.TEAM.REQUIRED_ERROR';
  }
  return errorMessage;
};

export default {
  name: {
    required,
    minLength: minLength(2),
  },
  selectedTeamId: {
    required,
  },
};
